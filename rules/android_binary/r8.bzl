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
"""R8 processor steps for android_binary."""

load("//providers:providers.bzl", "AndroidDexInfo", "AndroidPreDexJarInfo")
load("//rules:acls.bzl", "acls")
load("//rules:android_neverlink_aspect.bzl", "StarlarkAndroidNeverlinkInfo")
load("//rules:common.bzl", "common")
load("//rules:java.bzl", "java")
load("//rules:min_sdk_version.bzl", "min_sdk_version")
load(
    "//rules:processing_pipeline.bzl",
    "ProviderInfo",
)
load("//rules:proguard.bzl", "proguard")
load("//rules:resources.bzl", _resources = "resources")
load(
    "//rules:utils.bzl",
    "ANDROID_TOOLCHAIN_TYPE",
    "get_android_sdk",
    "get_android_toolchain",
    "utils",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

def process_r8(ctx, validation_ctx, jvm_ctx, packaged_resources_ctx, build_info_ctx, **_unused_ctxs):
    """Runs R8 for desugaring, optimization, and dexing.

    Args:
      ctx: Rule contxt.
      validation_ctx: Context from the base valdations processor.
      jvm_ctx: Context from the java processor.
      packaged_resources_ctx: Context from resource processing.
      build_info_ctx: Context from build info processor.
      **_unused_ctxs: Unused context.

    Returns:
      The r8_ctx ProviderInfo.
    """
    if not validation_ctx.use_r8:
        return ProviderInfo(
            name = "r8_ctx",
            value = struct(
                providers = [],
            ),
        )

    # The R8 processor step creates its own deploy jar instead of
    # The deploy jar from the deploy_jar processor is not used because as of now, whether it
    # actually produces a deploy jar is determinted by a separate set of ACLs, and also does
    # desugaring differently than with R8.
    deploy_jar = ctx.actions.declare_file(ctx.label.name + "_deploy.jar")
    java.create_deploy_jar(
        ctx,
        output = deploy_jar,
        runtime_jars = depset(
            direct = jvm_ctx.java_info.runtime_output_jars + [packaged_resources_ctx.class_jar],
            transitive = [jvm_ctx.java_info.transitive_runtime_jars],
        ),
        java_toolchain = common.get_java_toolchain(ctx),
        build_target = ctx.label.name,
        deploy_manifest_lines = build_info_ctx.deploy_manifest_lines,
        check_desugar_deps = ctx.fragments.android.check_desugar_deps,
    )

    dexes_zip = ctx.actions.declare_file(ctx.label.name + "_dexes.zip")
    proguard_mappings_output_file = ctx.actions.declare_file(ctx.label.name + "_proguard.map")

    # Extract proguard specs embedded in the deploy JAR (META-INF/proguard/
    # and META-INF/com.android.tools/) so they are passed to R8.
    jar_embedded_proguard = ctx.actions.declare_file(ctx.label.name + "_jar_embedded_proguard.pro")
    jar_extractor_args = ctx.actions.args()
    jar_extractor_args.add("--input_jar", deploy_jar)
    jar_extractor_args.add("--output_proguard_file", jar_embedded_proguard)
    ctx.actions.run(
        executable = get_android_toolchain(ctx).jar_embedded_proguard_extractor.files_to_run,
        arguments = [jar_extractor_args],
        inputs = [deploy_jar],
        outputs = [jar_embedded_proguard],
        mnemonic = "JarEmbeddedProguardExtractor",
        progress_message = "Extracting proguard specs from deploy jar for %{label}",
        toolchain = None,
    )

    android_jar = get_android_sdk(ctx).android_jar
    proguard_specs = proguard.get_proguard_specs(ctx, packaged_resources_ctx.resource_proguard_config) + [jar_embedded_proguard]

    # Get min SDK version from attribute, manifest_values, or depot floor
    effective_min_sdk = min_sdk_version.DEPOT_FLOOR
    min_sdk_attr = getattr(ctx.attr, "min_sdk_version", 0)
    if min_sdk_attr:
        effective_min_sdk = max(effective_min_sdk, min_sdk_attr)
    manifest_values = getattr(ctx.attr, "manifest_values", {})
    if "minSdkVersion" in manifest_values:
        manifest_min_sdk_str = manifest_values["minSdkVersion"]
        if manifest_min_sdk_str.isdigit():
            effective_min_sdk = max(effective_min_sdk, int(manifest_min_sdk_str))
        else:
            fail("minSdkVersion must be an integer")

    neverlink_infos = utils.collect_providers(StarlarkAndroidNeverlinkInfo, ctx.attr.deps)
    neverlink_jars = depset(transitive = [info.transitive_neverlink_libraries for info in neverlink_infos])

    args = ctx.actions.args()
    args.add("--release")
    args.add("--min-api", effective_min_sdk)
    args.add("--output", dexes_zip)
    args.add_all(proguard_specs, before_each = "--pg-conf")
    args.add("--lib", android_jar)
    args.add_all(neverlink_jars, before_each = "--lib")
    args.add(deploy_jar)  # jar to optimize + desugar + dex
    args.add("--pg-map-output", proguard_mappings_output_file)

    java.run(
        ctx = ctx,
        host_javabase = common.get_host_javabase(ctx),
        executable = get_android_toolchain(ctx).r8.files_to_run,
        arguments = [args],
        inputs = depset([android_jar, deploy_jar] + proguard_specs, transitive = [neverlink_jars]),
        outputs = [dexes_zip, proguard_mappings_output_file],
        mnemonic = "AndroidR8",
        jvm_flags = ["-Xmx8G"],
        progress_message = "R8 Optimizing, Desugaring, and Dexing %{label}",
    )

    android_dex_info = AndroidDexInfo(
        deploy_jar = deploy_jar,
        final_classes_dex_zip = dexes_zip,
        # R8 preserves the Java resources (i.e. non-Java-class files) in its output zip, so no need
        # to provide a Java resources zip.
        java_resource_jar = None,
    )

    return ProviderInfo(
        name = "r8_ctx",
        value = struct(
            final_classes_dex_zip = dexes_zip,
            dex_info = android_dex_info,
            providers = [
                android_dex_info,
                AndroidPreDexJarInfo(pre_dex_jar = deploy_jar),
            ],
        ),
    )

def process_resource_shrinking_r8(ctx, r8_ctx, packaged_resources_ctx, **_unused_ctxs):
    """Runs resource shrinking.

    Args:
      ctx: Rule contxt.
      r8_ctx: Context from the R8 processor.
      packaged_resources_ctx: Context from resource processing.
      **_unused_ctxs: Unused context.

    Returns:
      The r8_ctx ProviderInfo.
    """

    if (not acls.use_r8(str(ctx.label)) or
        not _resources.is_resource_shrinking_enabled(
            ctx.attr.shrink_resources,
            ctx.fragments.android.use_android_resource_shrinking,
            bool(ctx.files.proguard_specs),
        )):
        return ProviderInfo(
            name = "resource_shrinking_r8_ctx",
            value = struct(
                resource_apk_shrunk = None,
            ),
        )

    android_toolchain = get_android_toolchain(ctx)

    # 1. Convert the resource APK to proto format (resource shrinker operates on a proto apk)
    proto_resource_apk = ctx.actions.declare_file(ctx.label.name + "_proto_resource_apk.ap_")
    ctx.actions.run(
        arguments = [ctx.actions.args()
            .add("convert")
            .add(packaged_resources_ctx.resources_apk)  # input apk
            .add("-o", proto_resource_apk)  # output apk
            .add("--output-format", "proto")],
        executable = android_toolchain.aapt2.files_to_run,
        inputs = [packaged_resources_ctx.resources_apk],
        mnemonic = "Aapt2ConvertToProtoForResourceShrinkerR8",
        outputs = [proto_resource_apk],
        toolchain = ANDROID_TOOLCHAIN_TYPE,
    )

    # 2. Run the resource shrinker
    proto_resource_apk_shrunk = ctx.actions.declare_file(
        ctx.label.name + "_proto_resource_apk_shrunk.ap_",
    )
    java.run(
        ctx = ctx,
        host_javabase = common.get_host_javabase(ctx),
        executable = android_toolchain.resource_shrinker.files_to_run,
        arguments = [ctx.actions.args()
            .add("--input", proto_resource_apk)
            .add("--dex_input", r8_ctx.final_classes_dex_zip)
            .add("--output", proto_resource_apk_shrunk)],
        inputs = [proto_resource_apk, r8_ctx.final_classes_dex_zip],
        outputs = [proto_resource_apk_shrunk],
        mnemonic = "ResourceShrinkerForR8",
        progress_message = "Shrinking resources %{label}",
    )

    # 3. Convert back to a binary APK
    resource_apk_shrunk = ctx.actions.declare_file(ctx.label.name + "_resource_apk_shrunk.ap_")
    ctx.actions.run(
        arguments = [ctx.actions.args()
            .add("convert")
            .add(proto_resource_apk_shrunk)  # input apk
            .add("-o", resource_apk_shrunk)  # output apk
            .add("--output-format", "binary")],
        executable = android_toolchain.aapt2.files_to_run,
        inputs = [proto_resource_apk_shrunk],
        mnemonic = "Aapt2ConvertBackToBinaryForResourceShrinkerR8",
        outputs = [resource_apk_shrunk],
        toolchain = ANDROID_TOOLCHAIN_TYPE,
    )

    return ProviderInfo(
        name = "resource_shrinking_r8_ctx",
        value = struct(
            resource_apk_shrunk = resource_apk_shrunk,
        ),
    )
