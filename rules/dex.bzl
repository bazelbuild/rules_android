# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Bazel Dex Commands."""

load(":utils.bzl", "get_android_toolchain", "utils")
load(":providers.bzl", "StarlarkAndroidDexInfo")
load("@bazel_skylib//lib:collections.bzl", "collections")
load("//rules:attrs.bzl", _attrs = "attrs")

_tristate = _attrs.tristate

def _process_incremental_dexing(
        ctx,
        deps = [],
        runtime_jars = [],
        dexopts = [],
        main_dex_list = [],
        min_sdk_version = 0,
        java_info = None,
        desugar_dict = {},
        dexbuilder = None,
        dexmerger = None):
    classes_dex_zip = _get_dx_artifact(ctx, "classes.dex.zip")
    info = _merge_infos(utils.collect_providers(StarlarkAndroidDexInfo, deps))

    incremental_dexopts = _incremental_dexopts(dexopts, ctx.fragments.android.get_dexopts_supported_in_incremental_dexing)
    dex_archives_list = info.dex_archives_dict.get("".join(incremental_dexopts), depset()).to_list()
    dex_archives = _to_dexed_classpath(
        dex_archives_dict = {d.jar: d.dex for d in dex_archives_list},
        classpath = java_info.transitive_runtime_jars.to_list(),
        runtime_jars = runtime_jars,
    )

    for jar in runtime_jars:
        dex_archive = _get_dx_artifact(ctx, jar.basename + ".dex.zip")
        _dex(
            ctx,
            input = desugar_dict[jar] if jar in desugar_dict else jar,
            output = dex_archive,
            incremental_dexopts = incremental_dexopts,
            min_sdk_version = min_sdk_version,
            dex_exec = dexbuilder,
        )
        dex_archives.append(dex_archive)

    _dex_merge(
        ctx,
        output = classes_dex_zip,
        inputs = dex_archives,
        multidex_strategy = "minimal",
        main_dex_list = main_dex_list,
        dexopts = dexopts,
        dexmerger = dexmerger,
    )

    return classes_dex_zip

def _append_java8_legacy_dex(
        ctx,
        output = None,
        input = None,
        java8_legacy_dex = None,
        dex_zips_merger = None):
    args = ctx.actions.args()

    # Order matters here: we want java8_legacy_dex to be the highest-numbered classesN.dex
    args.add("--input_zip", input)
    args.add("--input_zip", java8_legacy_dex)
    args.add("--output_zip", output)

    ctx.actions.run(
        executable = dex_zips_merger,
        inputs = [input, java8_legacy_dex],
        outputs = [output],
        arguments = [args],
        mnemonic = "AppendJava8LegacyDex",
        use_default_shell_env = True,
        progress_message = "Adding Java8 legacy library for %s" % ctx.label,
    )

def _to_dexed_classpath(dex_archives_dict = {}, classpath = [], runtime_jars = []):
    dexed_classpath = []
    for jar in classpath:
        if jar not in dex_archives_dict:
            if jar not in runtime_jars:
                fail("Dependencies on .jar artifacts are not allowed in Android binaries, please use " +
                     "a java_import to depend on " + jar.short_path +
                     ". If this is an implicit dependency then the rule that " +
                     "introduces it will need to be fixed to account for it correctly.")
        else:
            dexed_classpath.append(dex_archives_dict[jar])
    return dexed_classpath

def _dex(
        ctx,
        input,
        output = None,
        incremental_dexopts = [],
        min_sdk_version = 0,
        dex_exec = None):
    """Dexes a JAR.

    Args:
        ctx: The context.
        input: File. The jar to be dexed.
        output: File. The archive file containing all of the dexes.
        incremental_dexopts: List of strings. Additional command-line flags for the dexing tool when building dexes.
        min_sdk_version: Integer. The minimum targeted sdk version.
        dex_exec: File. The executable dex builder file.
    """
    args = ctx.actions.args()

    args.add("--input_jar", input)
    args.add("--output_zip", output)
    args.add_all(incremental_dexopts)

    if min_sdk_version > 0:
        args.add("--min_sdk_version", min_sdk_version)

    execution_requirements = {}
    if ctx.fragments.android.persistent_android_dex_desugar:
        execution_requirements["supports-workers"] = 1
        if ctx.fragments.android.persistent_multiplex_android_dex_desugar:
            execution_requirements["supports-multiplex-workers"] = 1

    ctx.actions.run(
        executable = dex_exec,
        arguments = [args],
        inputs = [input],
        outputs = [output],
        mnemonic = "DexBuilder",
        progress_message = "Dexing " + input.path + " with applicable dexopts " + str(incremental_dexopts),
        execution_requirements = execution_requirements,
    )

def _get_dx_artifact(ctx, basename):
    return ctx.actions.declare_file("_dx_migrated/" + ctx.label.name + "/" + basename)

def _get_effective_incremental_dexing(
        force_incremental_dexing = _tristate.auto,
        has_forbidden_dexopts = False,
        incremental_dexing_after_proguard_by_default = True,
        incremental_dexing_shards_after_proguard = True,
        is_binary_optimized = False,
        use_incremental_dexing = True):
    if (is_binary_optimized and
        force_incremental_dexing == _tristate.yes and incremental_dexing_shards_after_proguard <= 0):
        fail("Target cannot be incrementally dexed because it uses Proguard")

    if force_incremental_dexing == _tristate.yes:
        return True

    if force_incremental_dexing == _tristate.no:
        return False

    # If there are incompatible dexopts and the incremental_dexing attr is not set, we silently don't run
    # incremental dexing.
    if has_forbidden_dexopts or (is_binary_optimized and not incremental_dexing_after_proguard_by_default):
        return False

    # use_incremental_dexing config flag will take effect if incremental_dexing attr is not set
    return use_incremental_dexing

def _get_java8_legacy_dex_and_map(ctx, build_customized_files = False, binary_jar = None, android_jar = None):
    if not build_customized_files:
        return utils.only(get_android_toolchain(ctx).java8_legacy_dex.files.to_list()), None
    else:
        java8_legacy_dex_rules = _get_dx_artifact(ctx, "_java8_legacy.dex.pgcfg")
        java8_legacy_dex_map = _get_dx_artifact(ctx, "_java8_legacy.dex.map")
        java8_legacy_dex = _get_dx_artifact(ctx, "_java8_legacy.dex.zip")

        args = ctx.actions.args()
        args.add("--rules", java8_legacy_dex_rules)
        args.add("--binary", binary_jar)
        args.add("--android_jar", android_jar)
        args.add("--output", java8_legacy_dex)
        args.add("--output_map", java8_legacy_dex_map)

        ctx.actions.run(
            executable = get_android_toolchain(ctx).build_java8_legacy_dex.files_to_run,
            inputs = [binary_jar, android_jar],
            outputs = [java8_legacy_dex_rules, java8_legacy_dex_map, java8_legacy_dex],
            arguments = [args],
            mnemonic = "BuildLegacyDex",
            progress_message = "Building Java8 legacy library for %s" % ctx.label,
        )

        return java8_legacy_dex, java8_legacy_dex_map

def _dex_merge(
        ctx,
        output = None,
        inputs = [],
        multidex_strategy = "minimal",
        main_dex_list = None,
        dexopts = [],
        dexmerger = None):
    args = ctx.actions.args()
    args.add("--multidex", multidex_strategy)
    args.add_all(inputs, before_each = "--input")
    args.add("--output", output)
    args.add_all(_merger_dexopts(dexopts, ctx.fragments.android.get_dexopts_supported_in_dex_merger))

    if main_dex_list:
        inputs.append(main_dex_list)
        args.add("-main_dex_list", main_dex_list)

    ctx.actions.run(
        executable = dexmerger,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "DexMerger",
        progress_message = "Assembling dex files into" + output.short_path,
    )

def _merger_dexopts(tokenized_dexopts, dexopts_supported_in_dex_merger):
    return _normalize_dexopts(_filter_dexopts(tokenized_dexopts, dexopts_supported_in_dex_merger))

def _incremental_dexopts(tokenized_dexopts, dexopts_supported_in_incremental_dexing):
    return _normalize_dexopts(_filter_dexopts(tokenized_dexopts, dexopts_supported_in_incremental_dexing))

def _merge_infos(infos):
    dex_archives_dict = {}
    for info in infos:
        for dexopts in info.dex_archives_dict:
            if dexopts not in dex_archives_dict:
                dex_archives_dict[dexopts] = [info.dex_archives_dict[dexopts]]
            else:
                dex_archives_dict[dexopts].append(info.dex_archives_dict[dexopts])
    return StarlarkAndroidDexInfo(
        dex_archives_dict =
            {dexopts: depset(direct = [], transitive = dex_archives) for dexopts, dex_archives in dex_archives_dict.items()},
    )

def _filter_dexopts(candidates, allowed):
    return [c for c in candidates if c in allowed]

def _normalize_dexopts(tokenized_dexopts):
    def _dx_to_dexbuilder(opt):
        return opt.replace("--no-", "--no")

    return collections.uniq(sorted([_dx_to_dexbuilder(token) for token in tokenized_dexopts]))

dex = struct(
    append_java8_legacy_dex = _append_java8_legacy_dex,
    dex = _dex,
    dex_merge = _dex_merge,
    get_dx_artifact = _get_dx_artifact,
    get_effective_incremental_dexing = _get_effective_incremental_dexing,
    get_java8_legacy_dex_and_map = _get_java8_legacy_dex_and_map,
    incremental_dexopts = _incremental_dexopts,
    merge_infos = _merge_infos,
    normalize_dexopts = _normalize_dexopts,
    process_incremental_dexing = _process_incremental_dexing,
)
