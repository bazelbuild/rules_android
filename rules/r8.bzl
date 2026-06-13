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

"""R8 processor steps for android_application/android_features."""

load(
    "//rules:busybox.bzl",
    _busybox = "busybox",
)
load(
    "//rules:utils.bzl",
    "ANDROID_TOOLCHAIN_TYPE",
    "get_android_sdk",
    "get_android_toolchain",
)
load("//rules:common.bzl", "common")
load("//rules:java.bzl", "java")
load(
    "//providers:providers.bzl",
    "AndroidDexInfo",
    "AndroidOptimizationInfo",
)

def filter_feature_jar(ctx, feature_name, feature_jar, base_jar):
    """Filter out feature jar by removing duplicated classes found in base jar.
    Args:
      ctx: Rule contxt.
      feature_name: The name of the feature, used to compute output file path
      feature_jar: The deploy jar of the feature module
      base_jar: The deploy jar of the base application

    Returns:
      A output file corresponding to the filtered jar.
    """

    output = ctx.actions.declare_file(ctx.label.name + "/filtered_modules/" + feature_name + ".jar")
    inputs = [base_jar, feature_jar]
    args = ctx.actions.args()
    args.add(output.path)
    args.add(base_jar.path)
    args.add(feature_jar.path)

    ctx.actions.run(
        executable = ctx.executable._filter_feature_classes_script,
        inputs = inputs,
        outputs = [output],
        arguments = [args],
        mnemonic = "FilterFeatureModule",
        progress_message = "Filtering jar for feature module '%s'" % feature_name,
        toolchain = None,
    )
    return output

def _process(ctx, deploy_jar, resource_info, proguard_specs, startup_profile = None, feature_split_jars = {}):
    """Runs R8 for desugaring, optimization, and dexing.
    Args:
      ctx: Rule contxt.
      deploy_jar: The deploy jar from java compilation..
      resource_info: [optional] The application resource info containing resource binary apk to shrink, i.e remove unsued resources.
      feature_split_jars: [optional] Dictionary of feature module jars to outputs.

    Returns:
      A AndroidDexInfo provider.
    """
    dexes_zip = ctx.actions.declare_file(ctx.label.name + "_dexes.zip")
    optimisation_info = None
    resource_apk = resource_info.resource_apk

    android_jar = get_android_sdk(ctx).android_jar

    inputs = [android_jar, deploy_jar] + proguard_specs
    outputs = [dexes_zip]

    min_sdk_version = getattr(ctx.attr, "min_sdk_version")
    if not min_sdk_version:
        min_sdk_version = 21
    args = ctx.actions.args()
    args.add("--release")
    args.add("--min-api", min_sdk_version)
    args.add("--output", dexes_zip)
    args.add_all(proguard_specs, before_each = "--pg-conf")
    args.add("--lib", android_jar)
    args.add("--pg-compat")

    # Convert resource APK to proto format, as expected by R8 tool
    if ctx.attr.shrink_resources:
        proto_resource_apk = ctx.actions.declare_file("proto_" + resource_apk.basename, sibling = resource_apk)
        ctx.actions.run(
            arguments = [ctx.actions.args()
                .add("convert")
                .add(resource_apk)
                .add("-o", proto_resource_apk)
                .add("--output-format", "proto")],
            executable = get_android_toolchain(ctx).aapt2.files_to_run,
            inputs = [resource_apk],
            mnemonic = "Aapt2ConvertToProtoForResourceShrinkerR8",
            outputs = [proto_resource_apk],
            toolchain = ANDROID_TOOLCHAIN_TYPE,
        )

        # Declare optimized proto APK R8 output, and include it on R8 command line parameters
        optimized_proto_apk = ctx.actions.declare_file("optimized_" + proto_resource_apk.basename, sibling=proto_resource_apk)
        args.add("--android-resources")
        args.add(proto_resource_apk)
        args.add(optimized_proto_apk)
        inputs.append(proto_resource_apk)
        outputs.append(optimized_proto_apk)

    for feature_jar, optimized_dex in feature_split_jars.items():
        feature_name = optimized_dex.path.split("/")[-1].lower()
        filtered_feature_jar = filter_feature_jar(ctx, feature_name, feature_jar, deploy_jar)
        args.add("--feature", filtered_feature_jar)
        args.add(optimized_dex.path)
        inputs.append(filtered_feature_jar)
        outputs.append(optimized_dex)

    args.add(deploy_jar)  # jar to optimize + desugar + dex

    proguard_output_map = ctx.actions.declare_file(ctx.label.name + "_proguard.map")
    merged_config_file = ctx.actions.declare_file(ctx.label.name + "_merged-config.pro")
    args.add("--pg-map-output", proguard_output_map)
    args.add("--pg-conf-output", merged_config_file)
    outputs.append(proguard_output_map)
    outputs.append(merged_config_file)

    if startup_profile:
        args.add("--startup-profile", startup_profile)
        inputs.append(startup_profile)

    java.run(
        ctx = ctx,
        host_javabase = common.get_host_javabase(ctx),
        executable = get_android_toolchain(ctx).r8.files_to_run,
        arguments = [args],
        inputs = inputs,
        outputs = outputs,
        jvm_flags = [
            "-Xms20g",
            "-Xmx20g",
        ],
        mnemonic = "AndroidR8Bundle",
        progress_message = "R8 Optimizing, Desugaring, and Dexing Bundle %{label}",
    )

    android_dex_info = AndroidDexInfo(
        deploy_jar = deploy_jar,
        final_classes_dex_zip = dexes_zip,
        final_proguard_output_map = proguard_output_map,
        # R8 preserves the Java resources (i.e. non-Java-class files) in its output zip, so no need
        # to provide a Java resources zip.
        java_resource_jar = None,
    )

    if ctx.attr.shrink_resources:

        # Run AAPT2 optimize on binary proto APK to obfuscate and shorten resources
        if ctx.attr.obfuscate_resources:
            obfuscated_resource_apk = ctx.actions.declare_file("obfuscated_" + resource_apk.basename, sibling = resource_apk)
            resource_path_shortening_map = ctx.actions.declare_file(ctx.label.name + "_resource_paths.map", sibling = resource_apk)
            _busybox.optimize(
                ctx,
                out_apk = obfuscated_resource_apk,
                in_apk = optimized_proto_apk,
                resource_path_shortening_map = resource_path_shortening_map,
                aapt = get_android_toolchain(ctx).aapt2.files_to_run,
                busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
                host_javabase = common.get_host_javabase(ctx),
            )
            optimized_proto_apk = obfuscated_resource_apk

        optimisation_info = AndroidOptimizationInfo(
            optimized_resource_apk = optimized_proto_apk,
            mapping = proguard_output_map,
            config = merged_config_file,
            resource_path_shortening_map = resource_path_shortening_map,
        )

    return android_dex_info, optimisation_info

r8 = struct(
    process = _process,
)
