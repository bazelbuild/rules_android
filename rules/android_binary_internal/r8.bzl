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

"""R8 processor steps for android_binary_internal."""

load("//rules:acls.bzl", "acls")
load("//rules:android_neverlink_aspect.bzl", "StarlarkAndroidNeverlinkInfo")
load("//rules:common.bzl", "common")
load("//rules:java.bzl", "java")
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
    if acls.in_android_binary_starlark_rollout(str(ctx.label)):
        deploy_jar = ctx.outputs.deploy_jar
    else:
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

    android_jar = get_android_sdk(ctx).android_jar
    proguard_specs = proguard.get_proguard_specs(ctx, packaged_resources_ctx.resource_proguard_config)
    min_sdk_version = getattr(ctx.attr, "min_sdk_version", None)

    neverlink_infos = utils.collect_providers(StarlarkAndroidNeverlinkInfo, ctx.attr.deps)
    neverlink_jars = depset(transitive = [info.transitive_neverlink_libraries for info in neverlink_infos])

    args = ctx.actions.args()
    args.add("--release")
    if min_sdk_version:
        args.add("--min-api", min_sdk_version)
    args.add("--output", dexes_zip)
    args.add_all(proguard_specs, before_each = "--pg-conf")
    args.add("--lib", android_jar)
    args.add_all(neverlink_jars, before_each = "--lib")
    args.add(deploy_jar)  # jar to optimize + desugar + dex

    java.run(
        ctx = ctx,
        host_javabase = common.get_host_javabase(ctx),
        executable = get_android_toolchain(ctx).r8.files_to_run,
        arguments = [args],
        inputs = depset([android_jar, deploy_jar] + proguard_specs, transitive = [neverlink_jars]),
        outputs = [dexes_zip],
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
            providers = [android_dex_info],
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
                android_application_resource_info_with_shrunk_resource_apk = None,
                providers = [],
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

    resource_shrinking_usage_log = ctx.actions.declare_file(ctx.label.name + "_resource_shrinking_usage.log")
    resource_shrinking_res_config = ctx.actions.declare_file(ctx.label.name + "_resources.cfg")
    args = ctx.actions.args()
    args.add("--input", proto_resource_apk)
    args.add("--dex_input", final_classes_dex_zip)

    args.add("--proguard_mapping", final_proguard_output_map)
    args.add("--output", proto_resource_apk_shrunk)
    args.add("--precise_shrinking", "true")
    args.add("--print_usage_log", resource_shrinking_usage_log)
    args.add("--print_config", resource_shrinking_res_config)

    java.run(
        ctx = ctx,
        host_javabase = common.get_host_javabase(ctx),
        executable = android_toolchain.resource_shrinker.files_to_run,
        arguments = [args],
        inputs = [proto_resource_apk, final_classes_dex_zip, final_proguard_output_map],
        outputs = [proto_resource_apk_shrunk, resource_shrinking_usage_log, resource_shrinking_res_config],
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

    # 4. Optimize resources (shorten resource path names, remove resource names, collapse resource values)
    resource_apk_optimized = ctx.actions.declare_file(ctx.label.name + "_resource_apk_optimized.ap_")
    resource_obfuscation_map = ctx.actions.declare_file(ctx.label.name + "_resource_obfuscation.map")
    ctx.actions.run(
        arguments = [ctx.actions.args()
            .add("optimize")
            .add(resource_apk_shrunk)
            .add("-o", resource_apk_optimized)
            .add("--resources-config-path", resource_shrinking_res_config)
            .add("--collapse-resource-names")
            .add("--shorten-resource-paths")
            .add("--deduplicate-entry-values")
            .add("--save-obfuscation-map", resource_obfuscation_map)
            ],
        executable = android_toolchain.aapt2.files_to_run,
        inputs = [resource_apk_shrunk, resource_shrinking_res_config],
        mnemonic = "Aapt2OptimizeForResourceShrinkerR8",
        outputs = [resource_apk_optimized, resource_obfuscation_map],
        toolchain = ANDROID_TOOLCHAIN_TYPE,
    )

    aari = android_application_resource

    # Replace the resource apk in the AndroidApplicationResourceInfo provider from resource
    # processing.
    new_aari = AndroidApplicationResourceInfo(
        resource_apk = resource_apk_optimized,
        resource_java_src_jar = aari.resource_java_src_jar,
        resource_java_class_jar = aari.resource_java_class_jar,
        manifest = aari.manifest,
        resource_proguard_config = aari.resource_proguard_config,
        main_dex_proguard_config = aari.main_dex_proguard_config,
        r_txt = aari.r_txt,
        resources_zip = aari.resources_zip,
        databinding_info = aari.databinding_info,
        should_compile_java_srcs = aari.should_compile_java_srcs,
    )

    return ProviderInfo(
        name = "resource_shrinking_r8_ctx",
        value = struct(
            android_application_resource_info_with_shrunk_resource_apk = new_aari,
            providers = [],
        ),
    )
