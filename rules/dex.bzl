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

load(":utils.bzl", "ANDROID_TOOLCHAIN_TYPE", "get_android_toolchain", "utils")
load(":providers.bzl", "StarlarkAndroidDexInfo")
load("@bazel_skylib//lib:collections.bzl", "collections")
load("//rules:attrs.bzl", _attrs = "attrs")
load("//rules:java.bzl", _java = "java")
load("//rules:common.bzl", _common = "common")

_tristate = _attrs.tristate

def _process_incremental_dexing(
        ctx,
        deps = [],
        runtime_jars = [],
        dexopts = [],
        main_dex_list = None,
        min_sdk_version = 0,
        inclusion_filter_jar = None,
        java_info = None,
        desugar_dict = {},
        dexsharder = None,
        dexbuilder = None,
        dexmerger = None,
        toolchain_type = None):
    classes_dex_zip = _get_dx_artifact(ctx, "classes.dex.zip")
    info = _merge_infos(utils.collect_providers(StarlarkAndroidDexInfo, deps))
    incremental_dexopts = _filter_dexopts(dexopts, ctx.fragments.android.get_dexopts_supported_in_incremental_dexing)
    dex_archives_list = info.dex_archives_dict.get("".join(incremental_dexopts), depset()).to_list()
    dex_archives = _to_dexed_classpath(
        dex_archives_dict = {d.jar: d.dex for d in dex_archives_list},
        classpath = _filter(java_info.transitive_runtime_jars.to_list(), excludes = _get_library_r_jars(deps)),
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
            toolchain_type = toolchain_type,
        )
        dex_archives.append(dex_archive)

    if len(dex_archives) == 1:
        _dex_merge(
            ctx,
            output = classes_dex_zip,
            inputs = dex_archives,
            multidex_strategy = "minimal",
            main_dex_list = main_dex_list,
            dexopts = _filter_dexopts(dexopts, ctx.fragments.android.get_dexopts_supported_in_dex_merger),
            dexmerger = dexmerger,
            toolchain_type = toolchain_type,
        )
    else:
        shards = ctx.actions.declare_directory("dexsplits/" + ctx.label.name)
        dexes = ctx.actions.declare_directory("dexfiles/" + ctx.label.name)
        _shard_dexes(
            ctx,
            output = shards,
            inputs = dex_archives,
            dexopts = _filter_dexopts(dexopts, ctx.fragments.android.get_dexopts_supported_in_dex_sharder),
            main_dex_list = main_dex_list,
            inclusion_filter_jar = inclusion_filter_jar,
            dexsharder = dexsharder,
            toolchain_type = toolchain_type,
        )

        # TODO(b/130571505): Implement this after SpawnActionTemplate is supported in Starlark
        android_common.create_dex_merger_actions(
            ctx,
            output = dexes,
            input = shards,
            dexopts = dexopts,
            dexmerger = dexmerger,
        )
        _java.singlejar(
            ctx,
            output = classes_dex_zip,
            inputs = [dexes],
            mnemonic = "MergeDexZips",
            progress_message = "Merging dex shards for %s." % ctx.label,
            java_toolchain = _common.get_java_toolchain(ctx),
        )

    return classes_dex_zip

def _shard_dexes(
        ctx,
        output,
        inputs = [],
        dexopts = [],
        main_dex_list = None,
        inclusion_filter_jar = None,
        dexsharder = None,
        toolchain_type = None):
    args = ctx.actions.args().use_param_file(param_file_arg = "@%s")
    args.add_all(inputs, before_each = "--input")
    args.add("--output", output.path)
    if main_dex_list:
        inputs.append(main_dex_list)
        args.add("--main-dex-list", main_dex_list)
    if inclusion_filter_jar:
        inputs.append(inclusion_filter_jar)
        args.add("--inclusion_filter_jar", inclusion_filter_jar)

    args.add_all(dexopts)

    ctx.actions.run(
        executable = dexsharder,
        outputs = [output],
        inputs = inputs,
        arguments = [args],
        mnemonic = "ShardsForMultiDex",
        progress_message = "Assembling dex files for " + ctx.label.name,
        use_default_shell_env = True,
        toolchain = toolchain_type,
    )

    return output

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
        toolchain = ANDROID_TOOLCHAIN_TYPE,
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
        dex_exec = None,
        toolchain_type = None):
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
        execution_requirements["supports-workers"] = "1"
        if ctx.fragments.android.persistent_multiplex_android_dex_desugar:
            execution_requirements["supports-multiplex-workers"] = "1"

    ctx.actions.run(
        executable = dex_exec,
        arguments = [args],
        inputs = [input],
        outputs = [output],
        mnemonic = "DexBuilder",
        progress_message = "Dexing " + input.path + " with applicable dexopts " + str(incremental_dexopts),
        execution_requirements = execution_requirements,
        toolchain = toolchain_type,
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
            toolchain = ANDROID_TOOLCHAIN_TYPE,
        )

        return java8_legacy_dex, java8_legacy_dex_map

def _get_library_r_jars(deps):
    transitive_resource_jars = []
    for dep in utils.collect_providers(AndroidLibraryResourceClassJarProvider, deps):
        transitive_resource_jars += dep.jars.to_list()
    return transitive_resource_jars

def _dex_merge(
        ctx,
        output = None,
        inputs = [],
        multidex_strategy = "minimal",
        main_dex_list = None,
        dexopts = [],
        dexmerger = None,
        toolchain_type = None):
    args = ctx.actions.args()
    args.add("--multidex", multidex_strategy)
    args.add_all(inputs, before_each = "--input")
    args.add("--output", output)
    args.add_all(dexopts)

    if main_dex_list:
        inputs.append(main_dex_list)
        args.add("--main-dex-list", main_dex_list)

    ctx.actions.run(
        executable = dexmerger,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "DexMerger",
        progress_message = "Assembling dex files into " + output.short_path,
        toolchain = toolchain_type,
    )

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

def _filter_dexopts(tokenized_dexopts, includes):
    return _normalize_dexopts(_filter(tokenized_dexopts, includes = includes))

def _filter(candidates, includes = [], excludes = []):
    if excludes and includes:
        fail("Only one of excludes list and includes list can be set.")
    if includes:
        return [c for c in candidates if c in includes]
    if excludes:
        return [c for c in candidates if c not in excludes]
    return candidates

def _normalize_dexopts(tokenized_dexopts):
    def _dx_to_dexbuilder(opt):
        return opt.replace("--no-", "--no")

    return collections.uniq(sorted([_dx_to_dexbuilder(token) for token in tokenized_dexopts]))

def _generate_main_dex_list(
        ctx,
        jar,
        android_jar = None,
        desugar_java8_libs = True,
        main_dex_classes = None,
        main_dex_list_opts = [],
        main_dex_proguard_spec = None,
        proguard_specs = [],
        legacy_apis = [],
        shrinked_android_jar = None,
        toolchain_type = None,
        main_dex_list_creator = None,
        legacy_main_dex_list_generator = None,
        proguard_tool = None):
    main_dex_list = _get_dx_artifact(ctx, "main_dex_list.txt")
    if not proguard_specs:
        proguard_specs.append(main_dex_classes)
    if main_dex_proguard_spec:
        proguard_specs.append(main_dex_proguard_spec)

    #  If legacy_main_dex_list_generator is not set by either the SDK or the flag, use ProGuard and
    #  the main dext list creator specified by the android_sdk rule. If
    #  legacy_main_dex_list_generator is provided, use that tool instead.
    #  TODO(b/147692286): Remove the old main-dex list generation that relied on ProGuard.
    if not legacy_main_dex_list_generator:
        if not shrinked_android_jar:
            fail("In \"legacy\" multidex mode, either legacy_main_dex_list_generator or " +
                 "shrinked_android_jar must be set in the android_sdk.")

        # Process the input jar through Proguard into an intermediate, streamlined jar.
        stripped_jar = _get_dx_artifact(ctx, "main_dex_intermediate.jar")
        args = ctx.actions.args()
        args.add("-forceprocessing")
        args.add("-injars", jar)
        args.add("-libraryjars", shrinked_android_jar)
        args.add("-outjars", stripped_jar)
        args.add("-dontwarn")
        args.add("-dontnote")
        args.add("-dontoptimize")
        args.add("-dontobfuscate")
        ctx.actions.run(
            outputs = [stripped_jar],
            executable = proguard_tool,
            args = [args],
            inputs = [jar, shrinked_android_jar],
            mnemonic = "MainDexClassesIntermediate",
            progress_message = "Generating streamlined input jar for main dex classes list",
            use_default_shell_dev = True,
            toolchain = toolchain_type,
        )

        args = ctx.actions.args()
        args.add_all([main_dex_list, stripped_jar, jar])
        args.add_all(main_dex_list_opts)

        ctx.actions.run(
            outputs = [main_dex_list],
            executable = main_dex_list_creator,
            arguments = [args],
            inputs = [jar, stripped_jar],
            mnemonic = "MainDexClasses",
            progress_message = "Generating main dex classes list",
            toolchain = toolchain_type,
        )
    else:
        inputs = [jar, android_jar] + proguard_specs

        args = ctx.actions.args()
        args.add("--main-dex-list-output", main_dex_list)
        args.add("--lib", android_jar)
        if desugar_java8_libs:
            args.add_all(legacy_apis, before_each = "--lib")
            inputs += legacy_apis
        args.add_all(proguard_specs, before_each = "--main-dex-rules")
        args.add(jar)
        ctx.actions.run(
            executable = legacy_main_dex_list_generator,
            arguments = [args],
            outputs = [main_dex_list],
            inputs = inputs,
            mnemonic = "MainDexClasses",
            progress_message = "Generating main dex classes list",
            toolchain = toolchain_type,
        )
    return main_dex_list

def _transform_dex_list_through_proguard_map(
        ctx,
        proguard_output_map = None,
        main_dex_list = None,
        toolchain_type = None,
        dex_list_obfuscator = None):
    if not proguard_output_map:
        return main_dex_list

    obfuscated_main_dex_list = _get_dx_artifact(ctx, "main_dex_list_obfuscated.txt")

    args = ctx.actions.args()
    args.add("--input", main_dex_list)
    args.add("--output", obfuscated_main_dex_list)
    args.add("--obfuscation_map", proguard_output_map)
    ctx.actions.run(
        executable = dex_list_obfuscator,
        arguments = [args],
        outputs = [obfuscated_main_dex_list],
        inputs = [main_dex_list],
        mnemonic = "MainDexProguardClasses",
        progress_message = "Obfuscating main dex classes list",
        toolchain = toolchain_type,
    )

    return obfuscated_main_dex_list

dex = struct(
    append_java8_legacy_dex = _append_java8_legacy_dex,
    dex = _dex,
    dex_merge = _dex_merge,
    generate_main_dex_list = _generate_main_dex_list,
    get_dx_artifact = _get_dx_artifact,
    get_effective_incremental_dexing = _get_effective_incremental_dexing,
    get_java8_legacy_dex_and_map = _get_java8_legacy_dex_and_map,
    filter_dexopts = _filter_dexopts,
    merge_infos = _merge_infos,
    normalize_dexopts = _normalize_dexopts,
    process_incremental_dexing = _process_incremental_dexing,
    transform_dex_list_through_proguard_map = _transform_dex_list_through_proguard_map,
)
