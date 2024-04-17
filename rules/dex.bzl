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

load("//rules:acls.bzl", "acls")
load("//rules:attrs.bzl", _attrs = "attrs")
load("//rules:common.bzl", _common = "common")
load("//rules:java.bzl", _java = "java")
load("@bazel_skylib//lib:collections.bzl", "collections")
load(":providers.bzl", "StarlarkAndroidDexInfo")
load(":utils.bzl", "ANDROID_TOOLCHAIN_TYPE", "get_android_toolchain", "utils")

_DEX_MEMORY = 4096
_DEX_THREADS = 5
_DEXOPTS_SUPPORTED_IN_DEXBUILDER = ["--no-locals", "--no-optimize", "--no-warnings", "--positions"]

_tristate = _attrs.tristate

def _resource_set_for_monolithic_dexing(_os, _inputs_size):
    return {"cpu": _DEX_THREADS, "memory": _DEX_MEMORY}

def _process_incremental_dexing(
        ctx,
        output,
        deps = [],
        runtime_jars = [],
        dexopts = [],
        native_multidex = True,
        main_dex_list = None,
        min_sdk_version = 0,
        proguarded_jar = None,
        library_jar = None,
        proguard_output_map = None,
        postprocessing_output_map = None,
        startup_profile = None,
        inclusion_filter_jar = None,
        desugar_dict = {},
        transitive_runtime_jars_for_archive = [],
        shuffle_jars = None,
        dexbuilder = None,
        dexbuilder_after_proguard = None,
        dexmerger = None,
        dexsharder = None,
        optimizing_dexer = None,
        min_sdk_config = None,
        toolchain_type = None):
    info = _merge_infos(utils.collect_providers(StarlarkAndroidDexInfo, deps))
    should_optimize_dex = optimizing_dexer and proguarded_jar and not acls.in_disable_optimizing_dexer(str(ctx.label))
    incremental_dexopts = _filter_dexopts(
        tokenized_dexopts = dexopts,
        includes = ctx.fragments.android.get_dexopts_supported_in_incremental_dexing,
        needs_normalization = not should_optimize_dex,
    )
    merger_dexopts = _filter_dexopts(
        tokenized_dexopts = dexopts,
        includes = ctx.fragments.android.get_dexopts_supported_in_dex_merger,
        needs_normalization = not should_optimize_dex,
    )
    if not proguarded_jar:
        dex_archives = []
        for jar in runtime_jars:
            dex_archive = _get_dx_artifact(ctx, jar.basename + ".dex.zip", min_sdk_version = min_sdk_version)
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

        # Use dicts rather than lists for more efficient filtering
        runtime_jars_dict = {jar: True for jar in runtime_jars}
        dex_archives += _to_dexed_classpath(
            dex_archives_dict = {d.jar: d.dex for d in info.dex_archives_dict.get("".join(incremental_dexopts), depset()).to_list()},
            classpath = transitive_runtime_jars_for_archive,
            runtime_jars_dict = runtime_jars_dict,
        )
    else:
        toplevel_dexbuilder_dexopts = _filter_dexopts(
            tokenized_dexopts = dexopts,
            includes = _DEXOPTS_SUPPORTED_IN_DEXBUILDER,
            needs_normalization = not should_optimize_dex,
        )
        java_resource_jar = ctx.actions.declare_file(ctx.label.name + "_files/java_resources.jar")
        if ctx.fragments.android.incremental_dexing_shards_after_proguard > 1:
            dex_archives = _shard_proguarded_jar_and_dex(
                ctx,
                java_resource_jar = java_resource_jar,
                num_shards = ctx.fragments.android.incremental_dexing_shards_after_proguard,
                dexopts = toplevel_dexbuilder_dexopts,
                proguarded_jar = proguarded_jar,
                main_dex_list = main_dex_list,
                min_sdk_version = min_sdk_version,
                shuffle_jars = shuffle_jars,
                dexbuilder_after_proguard = dexbuilder_after_proguard,
                optimizing_dexer = optimizing_dexer,
                min_sdk_config = min_sdk_config,
                toolchain_type = toolchain_type,
            )
            inclusion_filter_jar = None
        else:
            # No need to shuffle if there is only one shard
            dex_archive = _get_dx_artifact(ctx, "classes.jar", min_sdk_version = min_sdk_version)
            _dex(
                ctx,
                input = proguarded_jar,
                output = dex_archive,
                incremental_dexopts = toplevel_dexbuilder_dexopts,
                min_sdk_version = min_sdk_version,
                dex_exec = dexbuilder_after_proguard,
                toolchain_type = toolchain_type,
            )
            dex_archives = [dex_archive]

    if len(dex_archives) == 1:
        _dex_merge(
            ctx,
            output = output,
            inputs = dex_archives,
            multidex_strategy = "minimal",
            main_dex_list = main_dex_list,
            min_sdk_version = min_sdk_version,
            dexopts = merger_dexopts,
            dexmerger = dexmerger,
            toolchain_type = toolchain_type,
        )
    elif should_optimize_dex:
        _optimized_dex_merge(
            ctx,
            output = output,
            inputs = dex_archives,
            main_dex_list = main_dex_list,
            min_sdk_version = min_sdk_version,
            dexopts = merger_dexopts,
            native_multidex = native_multidex,
            library_jar = library_jar,
            proguard_output_map = proguard_output_map,
            postprocessing_output_map = postprocessing_output_map,
            startup_profile = startup_profile,
            optimizing_dexer = optimizing_dexer,
            min_sdk_config = min_sdk_config,
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
            min_sdk_version = min_sdk_version,
        )
        _java.singlejar(
            ctx,
            output = output,
            inputs = [dexes],
            mnemonic = "MergeDexZips",
            progress_message = "Merging dex shards for %s." % ctx.label,
            java_toolchain = _common.get_java_toolchain(ctx),
        )

def _process_monolithic_dexing(
        ctx,
        output,
        input,
        dexopts = [],
        min_sdk_version = 0,
        main_dex_list = None,
        dexbuilder = None,
        toolchain_type = None):
    # Create an artifact for the intermediate zip output generated by AndroidDexer that includes
    # non-.dex files. A subsequent TrimDexZip action will filter out all non-.dex files.
    classes_dex_intermediate = _get_dx_artifact(ctx, "intermediate_classes.dex.zip", min_sdk_version = min_sdk_version)
    inputs = [input]

    args = ctx.actions.args()
    args.add("--dex")
    args.add_all(dexopts)
    if min_sdk_version > 0:
        args.add("--min_sdk_version", min_sdk_version)
    args.add("--multi-dex")
    if main_dex_list:
        args.add(main_dex_list, format = "--main-dex-list=%s")
        inputs.append(main_dex_list)
    args.add(classes_dex_intermediate, format = "--output=%s")
    args.add(input)

    ctx.actions.run(
        executable = dexbuilder,
        inputs = inputs,
        outputs = [classes_dex_intermediate],
        arguments = [args],
        progress_message = "Converting %s to dex format" % input.short_path,
        mnemonic = "AndroidDexer",
        use_default_shell_env = True,
        resource_set = _resource_set_for_monolithic_dexing,
        toolchain = toolchain_type,
    )

    # Because the dexer also places resources into this zip, we also need to create a cleanup
    # action that removes all non-.dex files before staging for apk building.
    _java.singlejar(
        ctx,
        inputs = [classes_dex_intermediate],
        output = output,
        include_prefixes = ["classes"],
        java_toolchain = _common.get_java_toolchain(ctx),
        mnemonic = "TrimDexZip",
        progress_message = "Trimming %s." % classes_dex_intermediate.short_path,
    )

def _shard_proguarded_jar_and_dex(
        ctx,
        java_resource_jar,
        num_shards = 50,
        dexopts = [],
        proguarded_jar = None,
        main_dex_list = None,
        min_sdk_version = 0,
        shuffle_jars = None,
        dexbuilder_after_proguard = None,
        optimizing_dexer = None,
        min_sdk_config = None,
        toolchain_type = None):
    if num_shards <= 1:
        fail("num_shards expects to be larger than 1.")

    should_optimize_dex = optimizing_dexer and proguarded_jar and not acls.in_disable_optimizing_dexer(str(ctx.label))
    shard_suffix = ".zip" if should_optimize_dex else ".jar.dex.zip"
    shards = _make_shard_artifacts(ctx, num_shards, shard_suffix)
    shuffle_outputs = _make_shard_artifacts(ctx, num_shards, ".jar")
    inputs = []
    args = ctx.actions.args()
    args.add_all(shuffle_outputs, before_each = "--output_jar")
    args.add("--output_resources", java_resource_jar)

    if main_dex_list:
        args.add("--main_dex_filter", main_dex_list)
        inputs.append(main_dex_list)

    # If we need to run Proguard, all the class files will be in the Proguarded jar, which has to
    # be converted to dex.
    args.add("--input_jar", proguarded_jar)
    inputs.append(proguarded_jar)

    ctx.actions.run(
        executable = shuffle_jars,
        outputs = shuffle_outputs + [java_resource_jar],
        inputs = inputs,
        arguments = [args],
        mnemonic = "ShardClassesToDex",
        progress_message = "Sharding classes for dexing for " + str(ctx.label),
        use_default_shell_env = True,
        toolchain = toolchain_type,
    )

    for i in range(len(shards)):
        if should_optimize_dex:
            _optimizing_dex(
                ctx,
                input = shuffle_outputs[i],
                output = shards[i],
                incremental_dexopts = dexopts,
                min_sdk_version = min_sdk_version,
                dex_exec = optimizing_dexer,
                min_sdk_config = min_sdk_config,
                toolchain_type = toolchain_type,
            )
        else:
            _dex(
                ctx,
                input = shuffle_outputs[i],
                output = shards[i],
                incremental_dexopts = dexopts,
                min_sdk_version = min_sdk_version,
                dex_exec = dexbuilder_after_proguard,
                toolchain_type = toolchain_type,
            )
    return shards

def _make_shard_artifacts(ctx, n, suffix):
    return [_get_dx_artifact(ctx, "shard" + str(i) + suffix) for i in range(1, n + 1)]

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
        mnemonic = "ShardForMultidex",
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

def _to_dexed_classpath(dex_archives_dict = {}, classpath = [], runtime_jars_dict = {}):
    dexed_classpath = []
    for jar in classpath:
        if jar not in dex_archives_dict:
            if jar not in runtime_jars_dict:
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
        toolchain_type: The Android toolchain.
    """
    args = ctx.actions.args()
    args.use_param_file("@%s", use_always = True)  # Required for workers.
    args.set_param_file_format("multiline")

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

def _optimizing_dex(
        ctx,
        input,
        output = None,
        incremental_dexopts = [],
        min_sdk_version = 0,
        dex_exec = None,
        min_sdk_config = None,
        toolchain_type = None):
    """Performs optimizing intermediate dexing of a JAR.

    Args:
        ctx: The context.
        input: File. The jar to be dexed.
        output: File. The archive file containing all of the dexes.
        incremental_dexopts: List of strings. Additional command-line flags for the dexing tool when building dexes.
        min_sdk_version: Integer. The minimum targeted sdk version.
        dex_exec: File. The executable dex builder file.
        min_sdk_config: File. Contains a ProGuard config to define the min-sdk generated from the manifest.
        toolchain_type: The Android toolchain.
    """
    args = ctx.actions.args()
    args.add("--intermediate")
    args.add("--release")
    args.add("--no-desugaring")
    args.add("--output", output)
    args.add_all(incremental_dexopts)
    args.add(input)
    inputs = [input]

    if min_sdk_config:
        inputs.append(min_sdk_config)
        args.add("--min_api_pgcfg_file", min_sdk_config)
    elif min_sdk_version > 0:
        args.add("--min_sdk_version", min_sdk_version)

    ctx.actions.run(
        executable = dex_exec,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "ShardedOptimizingDex",
        progress_message = "Optimized dexing " + input.path + " with applicable dexopts " + str(incremental_dexopts),
        toolchain = toolchain_type,
    )

def _get_dx_artifact(ctx, basename, min_sdk_version = 0):
    min_sdk_version_part = ""
    if min_sdk_version:
        min_sdk_version_part = "sdk-" + str(min_sdk_version)
    return ctx.actions.declare_file("_dx/" + ctx.label.name + "/" + min_sdk_version_part + basename)

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

def _get_java8_legacy_dex_and_map(ctx, build_customized_files = False, binary_jar = None, android_jar = None, min_sdk_version = 0):
    if not build_customized_files:
        # TODO(b/329432231): Can we build this for each Android binary or generate one per minSdkVersion at least?
        return utils.only(get_android_toolchain(ctx).java8_legacy_dex.files.to_list()), None
    else:
        java8_legacy_dex_rules = _get_dx_artifact(ctx, "_java8_legacy.dex.pgcfg", min_sdk_version = min_sdk_version)
        java8_legacy_dex_map = _get_dx_artifact(ctx, "_java8_legacy.dex.map", min_sdk_version = min_sdk_version)
        java8_legacy_dex = _get_dx_artifact(ctx, "_java8_legacy.dex.zip", min_sdk_version = min_sdk_version)

        args = ctx.actions.args()
        args.add("--rules", java8_legacy_dex_rules)
        args.add("--binary", binary_jar)
        args.add("--android_jar", android_jar)
        args.add("--output", java8_legacy_dex)
        args.add("--output_map", java8_legacy_dex_map)
        if min_sdk_version:
            args.add("--min-api", min_sdk_version)

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

def _dex_merge(
        ctx,
        output = None,
        inputs = [],
        multidex_strategy = "minimal",
        main_dex_list = None,
        dexopts = [],
        min_sdk_version = 0,
        dexmerger = None,
        toolchain_type = None):
    args = ctx.actions.args()
    args.add("--multidex", multidex_strategy)
    args.add_all(inputs, before_each = "--input")
    args.add("--output", output)
    args.add_all(dexopts)

    if min_sdk_version:
        args.add("--min_sdk_version", min_sdk_version)
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

def _optimized_dex_merge(
        ctx,
        output = None,
        inputs = [],
        main_dex_list = None,
        min_sdk_version = 0,
        dexopts = [],
        native_multidex = True,
        library_jar = None,
        proguard_output_map = None,
        postprocessing_output_map = None,
        startup_profile = None,
        optimizing_dexer = None,
        min_sdk_config = None,
        toolchain_type = None):
    outputs = [output]

    # Use a param file to pass through all flags with paths that might get large.
    param_file = ctx.actions.declare_file(output.path + ".params")
    param_file_args = ctx.actions.args()
    param_file_args.add_all(inputs)
    param_file_args.add("--output", output)
    args = ctx.actions.args()
    args.add("--release")

    # --no-desugaring is unnecessary here. But it is left in for now to match
    # the native Blaze android_binary rules.
    # TODO(b/307352234): Drop --no-desugaring here after migrating off the
    # native android_binary rules.
    args.add("--no-desugaring")
    args.add_all(dexopts)

    if proguard_output_map:
        inputs.append(proguard_output_map)
        param_file_args.add("--pg-map", proguard_output_map)

    if postprocessing_output_map:
        param_file_args.add("--pg-map-output", postprocessing_output_map)
        outputs.append(postprocessing_output_map)

    if main_dex_list:
        inputs.append(main_dex_list)
        param_file_args.add("--main-dex-list", main_dex_list)

    if startup_profile and native_multidex:
        # Added to args instead of param_file_args since the addition of this flag should not
        # push bash over the 4096 character line limit, and this simplifies testing.
        args.add("--startup-profile", startup_profile)
        inputs.append(startup_profile)

    if min_sdk_config:
        inputs.append(min_sdk_config)
        args.add("--min_api_pgcfg_file", min_sdk_config)
    else:
        sdk = max(min_sdk_version, 21) if native_multidex else min_sdk_version
        if sdk > 0:
            args.add("--min-api", sdk)

    if main_dex_list:
        inputs.append(main_dex_list)
        param_file_args.add("--main-dex-list", main_dex_list)
    if library_jar:
        inputs.append(library_jar)
        param_file_args.add("--lib", library_jar)

    ctx.actions.write(
        param_file,
        content = param_file_args,
    )
    inputs.append(param_file)
    args.add("@" + param_file.path)

    ctx.actions.run(
        executable = optimizing_dexer,
        arguments = [args],
        inputs = inputs,
        outputs = outputs,
        mnemonic = "OptimizingDex",
        progress_message = "Optimized dexing for " + ctx.label.name,
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

def _filter_dexopts(
        tokenized_dexopts,
        includes,
        needs_normalization = True):
    filtered = [opt for opt in tokenized_dexopts if opt.split("=")[0] in includes]
    if needs_normalization:
        return _normalize_dexopts(filtered)
    else:
        return filtered

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
        inputs = [main_dex_list, proguard_output_map],
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
    process_monolithic_dexing = _process_monolithic_dexing,
    process_incremental_dexing = _process_incremental_dexing,
    transform_dex_list_through_proguard_map = _transform_dex_list_through_proguard_map,
)
