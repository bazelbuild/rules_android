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

load(":common.bzl", "common")
load(":utils.bzl", "ANDROID_TOOLCHAIN_TYPE", "utils")

_ProguardSpecContextInfo = provider(
    doc = "Contains data from processing Proguard specs.",
    fields = dict(
        proguard_configs = "The direct proguard configs",
        transitive_proguard_configs =
            "The proguard configs within the transitive closure of the target",
        providers = "The list of all providers to propagate.",
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
        proguard_dictionary = None,
        proguard_output_map = None,
        proguard_output_proto_map = None,
        proguard_seeds = None,
        proguard_usage = None,
        constant_string_deobfuscated_mapping = None,
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
      proguard_dictionary: File. Optional file to be used as a mapping for proguard. A line
        separated file of "words" to pull from when renaming classes and members during obfuscation.
        TODO(timpeut): verify whether this is still used.
      proguard_output_map: File. Optional file to be used to write the output map of obfuscated
        class and member names.
      proguard_output_proto_map: File. Optional file used to write a proto version of the output
        map.
      proguard_seeds: File. Optional file used to write the "seeds", which is a list of all
        classes and members which match a keep rule.
      proguard_usage: File. Optional file used to write all classes and members that are removed
        during shrinking (i.e. unused code).
      constant_string_deobfuscated_mapping: File. Optional output file.
        TODO(timpeut): verify whether this is still used.
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

    if proguard_dictionary:
        args.add("-obfuscationdictionary", proguard_dictionary)
        args.add("-classobfuscationdictionary", proguard_dictionary)
        args.add("-packageobfuscationdictionary", proguard_dictionary)
        inputs.append(proguard_dictionary)

    args.add_all(proguard_specs, format_each = "@%s")
    inputs.extend(proguard_specs)

    if proguard_output_map:
        args.add("-printmapping", proguard_output_map)
        outputs.append(proguard_output_map)

    if proguard_output_proto_map:
        args.add("-protomapping", proguard_output_proto_map)
        outputs.append(proguard_output_proto_map)

    if constant_string_deobfuscated_mapping:
        args.add("-obfuscatedconstantstringoutputfile", constant_string_deobfuscated_mapping)
        outputs.append(constant_string_deobfuscated_mapping)

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
    )

def _get_proguard_temp_artifact_with_prefix(ctx, label, prefix, name):
    native_label_name = label.name.removesuffix(common.PACKAGED_RESOURCES_SUFFIX)
    return ctx.actions.declare_file("proguard/" + native_label_name + "/" + prefix + "_" + native_label_name + "_" + name)

def _get_proguard_temp_artifact(ctx, name):
    return _get_proguard_temp_artifact_with_prefix(ctx, ctx.label, "MIGRATED", name)

def _get_proguard_output_map(ctx):
    return ctx.actions.declare_file(ctx.label.name.removesuffix(common.PACKAGED_RESOURCES_SUFFIX) + "_proguard_MIGRATED_.map")

proguard = struct(
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
)
