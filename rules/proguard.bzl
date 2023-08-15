# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""Bazel Android Proguard library for the Android rules."""

load(":android_neverlink_aspect.bzl", "StarlarkAndroidNeverlinkInfo")
load(":common.bzl", "common")
load(":java.bzl", "java")
load(":utils.bzl", "ANDROID_TOOLCHAIN_TYPE", "get_android_sdk", "utils")

_ProguardSpecContextInfo = provider(
    doc = "Contains data from processing Proguard specs.",
    fields = dict(
        proguard_configs = "The direct proguard configs",
        transitive_proguard_configs =
            "The proguard configs within the transitive closure of the target",
        providers = "The list of all providers to propagate.",
    ),
)

_ProguardOutputInfo = provider(
    doc = "Temporary provider to hold all proguard outputs. Will be replaced by a native  " +
          "provider. Useful for testing.",
    fields = dict(
        input_jar = "The input program jar, unoptimized",
        output_jar = "The optimized output jar",
        mapping = "Output proguard map",
        proto_mapping = "Output proto mapping",
        seeds = "Output seeds",
        usage = "Output usage",
        library_jar = "Merged library jar",
        config = "Output config",
    ),
)

def _validate_proguard_spec(
        ctx,
        out_validated_proguard_spec,
        proguard_spec,
        proguard_allowlister):
    args = ctx.actions.args()
    args.add("--path", proguard_spec)
    args.add("--output", out_validated_proguard_spec)

    ctx.actions.run(
        executable = proguard_allowlister,
        arguments = [args],
        inputs = [proguard_spec],
        outputs = [out_validated_proguard_spec],
        mnemonic = "ValidateProguard",
        progress_message = (
            "Validating proguard configuration %s" % proguard_spec.short_path
        ),
        toolchain = ANDROID_TOOLCHAIN_TYPE,
    )

def _process_specs(
        ctx,
        proguard_configs = [],
        proguard_spec_providers = [],
        proguard_allowlister = None):
    """Processes Proguard Specs

    Args:
      ctx: The context.
      proguard_configs: sequence of Files. A list of proguard config files to be
        processed. Optional.
      proguard_spec_providers: sequence of ProguardSpecProvider providers. A
        list of providers from the dependencies, exports, plugins,
        exported_plugins, etc. Optional.
      proguard_allowlister: The proguard_allowlister exeutable provider.

    Returns:
      A _ProguardSpecContextInfo provider.
    """

    # TODO(djwhang): Look to see if this can be just a validation action and the
    # proguard_spec provided by the rule can be propagated.
    validated_proguard_configs = []
    for proguard_spec in proguard_configs:
        validated_proguard_spec = ctx.actions.declare_file(
            "validated_proguard/%s/%s_valid" %
            (ctx.label.name, proguard_spec.path),
        )
        _validate_proguard_spec(
            ctx,
            validated_proguard_spec,
            proguard_spec,
            proguard_allowlister,
        )
        validated_proguard_configs.append(validated_proguard_spec)

    transitive_validated_proguard_configs = []
    for info in proguard_spec_providers:
        transitive_validated_proguard_configs.append(info.specs)

    transitive_proguard_configs = depset(
        validated_proguard_configs,
        transitive = transitive_validated_proguard_configs,
        order = "preorder",
    )
    return _ProguardSpecContextInfo(
        proguard_configs = proguard_configs,
        transitive_proguard_configs = transitive_proguard_configs,
        providers = [
            ProguardSpecProvider(transitive_proguard_configs),
            # TODO(b/152659272): Remove this once the android_archive rule is
            # able to process a transitive closure of deps to produce an aar.
            AndroidProguardInfo(proguard_configs),
        ],
    )

def _collect_transitive_proguard_specs(
        specs_to_include,
        local_proguard_specs,
        proguard_deps):
    if len(local_proguard_specs) == 0:
        return []

    proguard_specs = depset(
        local_proguard_specs + specs_to_include,
        transitive = [dep.specs for dep in proguard_deps],
    )
    return sorted(proguard_specs.to_list())

def _get_proguard_specs(
        ctx,
        resource_proguard_config,
        proguard_specs_for_manifest = []):
    proguard_deps = utils.collect_providers(ProguardSpecProvider, utils.dedupe_split_attr(ctx.split_attr.deps))
    if ctx.configuration.coverage_enabled and hasattr(ctx.attr, "_jacoco_runtime"):
        proguard_deps.append(ctx.attr._jacoco_runtime[ProguardSpecProvider])

    local_proguard_specs = []
    if ctx.files.proguard_specs:
        local_proguard_specs = ctx.files.proguard_specs
    proguard_specs = _collect_transitive_proguard_specs(
        [resource_proguard_config],
        local_proguard_specs,
        proguard_deps,
    )

    if len(proguard_specs) > 0 and ctx.fragments.android.assume_min_sdk_version:
        # NB: Order here is important. We're including generated Proguard specs before the user's
        # specs so that they can override values.
        proguard_specs = proguard_specs_for_manifest + proguard_specs

    return proguard_specs

def _generate_min_sdk_version_assumevalues(
        ctx,
        output = None,
        manifest = None,
        generate_exec = None):
    """Reads the minSdkVersion from an AndroidManifest to generate Proguard specs."""
    args = ctx.actions.args()
    inputs = []
    outputs = []

    args.add("--manifest", manifest)
    inputs.append(manifest)

    args.add("--output", output)
    outputs.append(output)

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = generate_exec,
        arguments = [args],
        mnemonic = "MinSdkVersionAssumeValuesProguardSpecGenerator",
        progress_message = "Adding -assumevalues spec for minSdkVersion",
    )

def _optimization_action(
        ctx,
        output_jar,
        program_jar,
        library_jar,
        proguard_specs,
        proguard_mapping = None,
        proguard_output_map = None,
        proguard_seeds = None,
        proguard_usage = None,
        proguard_config_output = None,
        runtype = None,
        last_stage_output = None,
        next_stage_output = None,
        final = False,
        mnemonic = None,
        progress_message = None,
        proguard_tool = None):
    """Creates a Proguard optimization action.

    This method is expected to be called one or more times to create Proguard optimization actions.
    Most outputs will only be generated by the final optimization action, and should otherwise be
    set to None. For the final action set `final = True` which will register the output_jar as an
    output of the action.

    TODO(b/286955442): Support baseline profiles.

    Args:
      ctx: The context.
      output_jar: File. The final output jar.
      program_jar: File. The jar to be optimized.
      library_jar: File. The merged library jar. While the underlying tooling supports multiple
        library jars, we merge these into a single jar before processing.
      proguard_specs: Sequence of files. A list of proguard specs to use for the optimization.
      proguard_mapping: File. Optional file to be used as a mapping for proguard. A mapping file
        generated by proguard_generate_mapping to be re-used to apply the same map to a new build.
      proguard_output_map: File. Optional file to be used to write the output map of obfuscated
        class and member names.
      proguard_seeds: File. Optional file used to write the "seeds", which is a list of all
        classes and members which match a keep rule.
      proguard_usage: File. Optional file used to write all classes and members that are removed
        during shrinking (i.e. unused code).
      proguard_config_output:File. Optional file used to write the entire configuration that has
        been parsed, included files and replaced variables. Useful for debugging.
      runtype: String. Optional string identifying this run. One of [INITIAL, OPTIMIZATION, FINAL]
      last_stage_output: File. Optional input file to this optimization stage, which was output by
        the previous optimization stage.
      next_stage_output: File. Optional output file from this optimization stage, which will be
        consunmed by the next optimization stage.
      final: Boolean. Whether this is the final optimization stage, which will register output_jar
        as an output of this action.
      mnemonic: String. Action mnemonic.
      progress_message: String. Action progress message.
      proguard_tool: FilesToRunProvider. The proguard tool to execute.

    Returns:
      None
    """

    inputs = []
    outputs = []
    args = ctx.actions.args()

    args.add("-forceprocessing")

    args.add("-injars", program_jar)
    inputs.append(program_jar)

    args.add("-outjars", output_jar)
    if final:
        outputs.append(output_jar)

    args.add("-libraryjars", library_jar)
    inputs.append(library_jar)

    if proguard_mapping:
        args.add("-applymapping", proguard_mapping)
        inputs.append(proguard_mapping)

    args.add_all(proguard_specs, format_each = "@%s")
    inputs.extend(proguard_specs)

    if proguard_output_map:
        args.add("-printmapping", proguard_output_map)
        outputs.append(proguard_output_map)

    if proguard_seeds:
        args.add("-printseeds", proguard_seeds)
        outputs.append(proguard_seeds)

    if proguard_usage:
        args.add("-printusage", proguard_usage)
        outputs.append(proguard_usage)

    if proguard_config_output:
        args.add("-printconfiguration", proguard_config_output)
        outputs.append(proguard_config_output)

    if runtype:
        args.add("-runtype " + runtype)

    if last_stage_output:
        args.add("-laststageoutput", last_stage_output)
        inputs.append(last_stage_output)

    if next_stage_output:
        args.add("-nextstageoutput", next_stage_output)
        outputs.append(next_stage_output)

    ctx.actions.run(
        outputs = outputs,
        inputs = inputs,
        executable = proguard_tool,
        arguments = [args],
        mnemonic = mnemonic,
        progress_message = progress_message,
        toolchain = None,  # TODO(timpeut): correctly set this based off which optimizer is selected
    )

def _get_proguard_temp_artifact_with_prefix(ctx, label, prefix, name):
    native_label_name = label.name.removesuffix(common.PACKAGED_RESOURCES_SUFFIX)
    return ctx.actions.declare_file("proguard/" + native_label_name + "/" + prefix + "_" + native_label_name + "_" + name)

def _get_proguard_temp_artifact(ctx, name):
    return _get_proguard_temp_artifact_with_prefix(ctx, ctx.label, "MIGRATED", name)

def _get_proguard_output_map(ctx):
    return ctx.actions.declare_file(ctx.label.name.removesuffix(common.PACKAGED_RESOURCES_SUFFIX) + "_proguard_MIGRATED_.map")

def _apply_proguard(
        ctx,
        input_jar = None,
        proguard_specs = [],
        proguard_optimization_passes = None,
        proguard_mapping = None,
        proguard_output_jar = None,
        proguard_output_map = None,
        proguard_seeds = None,
        proguard_usage = None,
        proguard_tool = None):
    """Top-level method to apply proguard to a jar.

    Args:
      ctx: The context
      input_jar: File. The input jar to optimized.
      proguard_specs: List of Files. The proguard specs to use for optimization.
      proguard_optimization_passes: Integer. The number of proguard passes to apply.
      proguard_mapping: File. The proguard mapping to apply.
      proguard_output_jar: File. The output optimized jar.
      proguard_output_map: File. The output proguard map.
      proguard_seeds: File. The output proguard seeds.
      proguard_usage: File. The output proguard usage.
      proguard_tool: FilesToRun. The proguard executable.

    Returns:
      A struct of proguard outputs, corresponding to the fields in ProguardOutputInfo.
    """
    if not proguard_specs:
        # Fail at execution time if these artifacts are requested, to avoid issue where outputs are
        # declared without having any proguard specs. This can happen if specs is a select() that
        # resolves to an empty list.
        _fail_action(
            ctx,
            proguard_output_jar,
            proguard_output_map,
            proguard_seeds,
            proguard_usage,
        )
        return None

    library_jar_list = [get_android_sdk(ctx).android_jar]
    if ctx.fragments.android.desugar_java8:
        library_jar_list.append(ctx.file._desugared_java8_legacy_apis)
    neverlink_infos = utils.collect_providers(StarlarkAndroidNeverlinkInfo, ctx.attr.deps)
    library_jars = depset(library_jar_list, transitive = [info.transitive_neverlink_libraries for info in neverlink_infos])

    return _create_optimization_actions(
        ctx,
        proguard_specs,
        proguard_seeds,
        proguard_usage,
        proguard_mapping,
        proguard_output_jar,
        proguard_optimization_passes,
        proguard_output_map,
        input_jar,
        library_jars,
        proguard_tool,
    )

def _get_proguard_output(
        ctx,
        proguard_output_jar,
        proguard_seeds,
        proguard_usage,
        proguard_output_map,
        combined_library_jar):
    """Helper method to get a struct of all proguard outputs."""
    config_output = _get_proguard_temp_artifact(ctx, "_proguard.config")

    return struct(
        output_jar = proguard_output_jar,
        mapping = proguard_output_map,
        seeds = proguard_seeds,
        usage = proguard_usage,
        library_jar = combined_library_jar,
        config = config_output,
    )

def _create_optimization_actions(
        ctx,
        proguard_specs = None,
        proguard_seeds = None,
        proguard_usage = None,
        proguard_mapping = None,
        proguard_output_jar = None,
        num_passes = None,
        proguard_output_map = None,
        input_jar = None,
        library_jars = depset(),
        proguard_tool = None):
    """Helper method to create all optimizaction actions based on the target configuration."""
    if not proguard_specs:
        fail("Missing proguard_specs in create_optimization_actions")

    # Merge all library jars into a single jar
    combined_library_jar = _get_proguard_temp_artifact(ctx, "_migrated_combined_library_jars.jar")
    java.singlejar(
        ctx,
        library_jars,
        combined_library_jar,
        java_toolchain = common.get_java_toolchain(ctx),
    )

    # Filter library jar with program jar
    filtered_library_jar = _get_proguard_temp_artifact(ctx, "_migrated_combined_library_jars_filtered.jar")
    common.filter_zip_exclude(
        ctx,
        filtered_library_jar,
        combined_library_jar,
        filter_zips = [input_jar],
    )

    outputs = _get_proguard_output(
        ctx,
        proguard_output_jar,
        proguard_seeds,
        proguard_usage,
        proguard_output_map,
        combined_library_jar,
    )

    # TODO(timpeut): Validate that optimizer target selection is correct
    mnemonic = ctx.fragments.java.bytecode_optimizer_mnemonic
    optimizer_target = ctx.executable._bytecode_optimizer

    # If num_passes is not specified run a single optimization action
    if not num_passes:
        _optimization_action(
            ctx,
            outputs.output_jar,
            input_jar,
            filtered_library_jar,
            proguard_specs,
            proguard_mapping = proguard_mapping,
            proguard_output_map = outputs.mapping,
            proguard_seeds = outputs.seeds,
            proguard_usage = outputs.usage,
            proguard_config_output = outputs.config,
            final = True,
            mnemonic = mnemonic,
            progress_message = "Trimming binary with %s: %s" % (mnemonic, ctx.label),
            proguard_tool = proguard_tool,
        )
        return outputs

    # num_passes has been specified, create multiple proguard actions
    split_bytecode_optimization_passes = ctx.fragments.java.split_bytecode_optimization_pass
    bytecode_optimization_pass_actions = ctx.fragments.java.bytecode_optimization_pass_actions
    last_stage_output = _get_proguard_temp_artifact(ctx, "_proguard_preoptimization.jar")
    _optimization_action(
        ctx,
        outputs.output_jar,
        input_jar,
        filtered_library_jar,
        proguard_specs,
        proguard_mapping = proguard_mapping,
        proguard_output_map = None,
        proguard_seeds = outputs.seeds,
        proguard_usage = None,
        proguard_config_output = None,
        final = False,
        runtype = "INITIAL",
        next_stage_output = last_stage_output,
        mnemonic = mnemonic,
        progress_message = "Trimming binary with %s: Verification/Shrinking Pass" % mnemonic,
        proguard_tool = proguard_tool,
    )
    for i in range(1, num_passes + 1):
        if split_bytecode_optimization_passes and bytecode_optimization_pass_actions < 2:
            last_stage_output = _create_single_optimization_action(
                ctx,
                outputs.output_jar,
                input_jar,
                filtered_library_jar,
                proguard_specs,
                proguard_mapping,
                i,
                "_INITIAL",
                mnemonic,
                last_stage_output,
                optimizer_target,
            )
            last_stage_output = _create_single_optimization_action(
                ctx,
                outputs.output_jar,
                input_jar,
                filtered_library_jar,
                proguard_specs,
                proguard_mapping,
                i,
                "_FINAL",
                mnemonic,
                last_stage_output,
                optimizer_target,
            )
        else:
            for j in range(1, bytecode_optimization_pass_actions + 1):
                last_stage_output = _create_single_optimization_action(
                    ctx,
                    outputs.output_jar,
                    input_jar,
                    filtered_library_jar,
                    proguard_specs,
                    proguard_mapping,
                    i,
                    "_ACTION_%s_OF_%s_" % (j, bytecode_optimization_pass_actions),
                    mnemonic,
                    last_stage_output,
                    optimizer_target,
                )

    _optimization_action(
        ctx,
        outputs.output_jar,
        input_jar,
        filtered_library_jar,
        proguard_specs,
        proguard_mapping = proguard_mapping,
        proguard_output_map = outputs.mapping,
        proguard_seeds = None,
        proguard_usage = outputs.usage,
        proguard_config_output = outputs.config,
        final = True,
        runtype = "FINAL",
        last_stage_output = last_stage_output,
        mnemonic = mnemonic,
        progress_message = "Trimming binary with %s: Obfuscation and Final Output Pass" % mnemonic,
        proguard_tool = proguard_tool,
    )
    return outputs

def _create_single_optimization_action(
        ctx,
        output_jar,
        program_jar,
        library_jar,
        proguard_specs,
        proguard_mapping,
        optimization_pass_num,
        runtype_suffix,
        mnemonic,
        last_stage_output,
        proguard_tool):
    next_stage_output = _get_proguard_temp_artifact(ctx, "_%s_optimization%s_%s.jar" % (mnemonic, runtype_suffix, optimization_pass_num))
    _optimization_action(
        ctx,
        output_jar,
        program_jar,
        library_jar,
        proguard_specs,
        proguard_mapping = proguard_mapping,
        mnemonic = mnemonic,
        final = False,
        runtype = "OPTIMIZATION" + runtype_suffix,
        last_stage_output = last_stage_output,
        next_stage_output = next_stage_output,
        progress_message = "Trimming binary with %s: Optimization%s Pass %d" % (mnemonic, runtype_suffix, optimization_pass_num),
        proguard_tool = proguard_tool,
    )
    return next_stage_output

def _fail_action(ctx, *outputs):
    ctx.actions.run_shell(
        outputs = outputs,
        command = "echo \"Unable to run proguard without `proguard_specs`\"; exit 1;",
    )

proguard = struct(
    apply_proguard = _apply_proguard,
    process_specs = _process_specs,
    generate_min_sdk_version_assumevalues = _generate_min_sdk_version_assumevalues,
    get_proguard_output_map = _get_proguard_output_map,
    get_proguard_specs = _get_proguard_specs,
    get_proguard_temp_artifact = _get_proguard_temp_artifact,
    get_proguard_temp_artifact_with_prefix = _get_proguard_temp_artifact_with_prefix,
)

testing = struct(
    validate_proguard_spec = _validate_proguard_spec,
    collect_transitive_proguard_specs = _collect_transitive_proguard_specs,
    optimization_action = _optimization_action,
    ProguardSpecContextInfo = _ProguardSpecContextInfo,
    ProguardOutputInfo = _ProguardOutputInfo,
)
