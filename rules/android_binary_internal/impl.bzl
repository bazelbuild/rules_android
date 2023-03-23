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

"""Implementation."""

load("//rules:acls.bzl", "acls")
load("//rules:common.bzl", "common")
load("//rules:data_binding.bzl", "data_binding")
load("//rules:java.bzl", "java")
load(
    "//rules:processing_pipeline.bzl",
    "ProviderInfo",
    "processing_pipeline",
)
load("//rules:resources.bzl", _resources = "resources")
load("//rules:utils.bzl", "compilation_mode", "get_android_toolchain", "utils")
load(
    "//rules:native_deps.bzl",
    _process_native_deps = "process",
)

def _process_manifest(ctx, **unused_ctxs):
    manifest_ctx = _resources.bump_min_sdk(
        ctx,
        manifest = ctx.file.manifest,
        floor = _resources.DEPOT_MIN_SDK_FLOOR if (_is_test_binary(ctx) and acls.in_enforce_min_sdk_floor_rollout(str(ctx.label))) else 0,
        enforce_min_sdk_floor_tool = get_android_toolchain(ctx).enforce_min_sdk_floor_tool.files_to_run,
    )

    return ProviderInfo(
        name = "manifest_ctx",
        value = manifest_ctx,
    )

def _process_resources(ctx, manifest_ctx, java_package, **unused_ctxs):
    packaged_resources_ctx = _resources.package(
        ctx,
        assets = ctx.files.assets,
        assets_dir = ctx.attr.assets_dir,
        resource_files = ctx.files.resource_files,
        manifest = manifest_ctx.processed_manifest,
        manifest_values = utils.expand_make_vars(ctx, ctx.attr.manifest_values),
        resource_configs = ctx.attr.resource_configuration_filters,
        densities = ctx.attr.densities,
        nocompress_extensions = ctx.attr.nocompress_extensions,
        java_package = java_package,
        compilation_mode = compilation_mode.get(ctx),
        shrink_resources = ctx.attr.shrink_resources,
        use_android_resource_shrinking = ctx.fragments.android.use_android_resource_shrinking,
        use_android_resource_cycle_shrinking = ctx.fragments.android.use_android_resource_cycle_shrinking,
        use_legacy_manifest_merger = use_legacy_manifest_merger(ctx),
        should_throw_on_conflict = not acls.in_allow_resource_conflicts(str(ctx.label)),
        enable_data_binding = ctx.attr.enable_data_binding,
        enable_manifest_merging = ctx.attr._enable_manifest_merging,
        deps = utils.dedupe_split_attr(ctx.split_attr.deps),
        instruments = ctx.attr.instruments,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
        android_jar = ctx.attr._android_sdk[AndroidSdkInfo].android_jar,
        legacy_merger = ctx.attr._android_manifest_merge_tool.files_to_run,
        xsltproc = ctx.attr._xsltproc_tool.files_to_run,
        instrument_xslt = ctx.file._add_g3itr_xslt,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        host_javabase = ctx.attr._host_javabase,
    )
    return ProviderInfo(
        name = "packaged_resources_ctx",
        value = packaged_resources_ctx,
    )

def _validate_manifest(ctx, packaged_resources_ctx, **unused_ctxs):
    manifest_validation_ctx = _resources.validate_min_sdk(
        ctx,
        manifest = packaged_resources_ctx.processed_manifest,
        floor = _resources.DEPOT_MIN_SDK_FLOOR if acls.in_enforce_min_sdk_floor_rollout(str(ctx.label)) else 0,
        enforce_min_sdk_floor_tool = get_android_toolchain(ctx).enforce_min_sdk_floor_tool.files_to_run,
    )

    return ProviderInfo(
        name = "manifest_validation_ctx",
        value = manifest_validation_ctx,
    )

def _process_native_libs(ctx, **_unusued_ctxs):
    providers = []
    if acls.in_android_binary_starlark_split_transition(str(ctx.label)):
        providers.append(_process_native_deps(
            ctx,
            filename = "nativedeps",
        ))
    return ProviderInfo(
        name = "native_libs_ctx",
        value = struct(providers = providers),
    )

def _process_build_stamp(_unused_ctx, **_unused_ctxs):
    return ProviderInfo(
        name = "stamp_ctx",
        value = struct(
            resource_files = [],
            deps = [],
            java_info = None,
            providers = [],
        ),
    )

def _process_data_binding(ctx, java_package, packaged_resources_ctx, **_unused_ctxs):
    if ctx.attr.enable_data_binding and not acls.in_databinding_allowed(str(ctx.label)):
        fail("This target is not allowed to use databinding and enable_data_binding is True.")
    return ProviderInfo(
        name = "db_ctx",
        value = data_binding.process(
            ctx,
            defines_resources = True,
            enable_data_binding = ctx.attr.enable_data_binding,
            java_package = java_package,
            layout_info = packaged_resources_ctx.data_binding_layout_info,
            artifact_type = "APPLICATION",
            deps = utils.collect_providers(DataBindingV2Info, utils.dedupe_split_attr(ctx.split_attr.deps)),
            data_binding_exec = get_android_toolchain(ctx).data_binding_exec.files_to_run,
            data_binding_annotation_processor =
                get_android_toolchain(ctx).data_binding_annotation_processor[JavaPluginInfo],
            data_binding_annotation_template =
                utils.only(get_android_toolchain(ctx).data_binding_annotation_template.files.to_list()),
        ),
    )

def _process_jvm(ctx, db_ctx, packaged_resources_ctx, stamp_ctx, **_unused_ctxs):
    native_name = ctx.label.name.removesuffix(common.PACKAGED_RESOURCES_SUFFIX)
    java_info = java.compile_android(
        ctx,
        # Use the same format as the class jar from native android_binary.
        # Some macros expect the class jar to be named like this.
        ctx.actions.declare_file("%s/lib%s.jar" % (ctx.label.name, native_name)),
        ctx.actions.declare_file(ctx.label.name + "-src.jar"),
        srcs = ctx.files.srcs + db_ctx.java_srcs,
        javac_opts = ctx.attr.javacopts + db_ctx.javac_opts,
        r_java = packaged_resources_ctx.r_java,
        enable_deps_without_srcs = True,
        deps = utils.collect_providers(JavaInfo, utils.dedupe_split_attr(ctx.split_attr.deps) + stamp_ctx.deps),
        plugins =
            utils.collect_providers(JavaPluginInfo, ctx.attr.plugins) +
            db_ctx.java_plugins,
        annotation_processor_additional_outputs =
            db_ctx.java_annotation_processor_additional_outputs,
        annotation_processor_additional_inputs =
            db_ctx.java_annotation_processor_additional_inputs,
        strict_deps = "DEFAULT",
        java_toolchain = common.get_java_toolchain(ctx),
    )
    java_info = java_common.add_constraints(
        java_info,
        constraints = ["android"],
    )

    providers = []
    if acls.in_android_binary_starlark_javac(str(ctx.label)):
        providers.append(java_info)

    return ProviderInfo(
        name = "jvm_ctx",
        value = struct(
            java_info = java_info,
            providers = providers,
        ),
    )

def use_legacy_manifest_merger(ctx):
    """Whether legacy manifest merging is enabled.

    Args:
      ctx: The context.

    Returns:
      Boolean indicating whether legacy manifest merging is enabled.
    """
    manifest_merger = ctx.attr.manifest_merger
    android_manifest_merger = ctx.fragments.android.manifest_merger

    if android_manifest_merger == "force_android":
        return False
    if manifest_merger == "auto":
        manifest_merger = android_manifest_merger

    return manifest_merger == "legacy"

def finalize(ctx, providers, validation_outputs, **unused_ctxs):
    providers.append(
        OutputGroupInfo(
            _validation = depset(validation_outputs),
        ),
    )
    return providers

def _is_test_binary(ctx):
    """Whether this android_binary target is a test binary.

    Args:
      ctx: The context.

    Returns:
      Boolean indicating whether the target is a test target.
    """
    return ctx.attr.testonly or ctx.attr.instruments or str(ctx.label).find("/javatests/") >= 0

# Order dependent, as providers will not be available to downstream processors
# that may depend on the provider. Iteration order for a dictionary is based on
# insertion.
PROCESSORS = dict(
    ManifestProcessor = _process_manifest,
    StampProcessor = _process_build_stamp,
    ResourceProcessor = _process_resources,
    ValidateManifestProcessor = _validate_manifest,
    NativeLibsProcessor = _process_native_libs,
    DataBindingProcessor = _process_data_binding,
    JvmProcessor = _process_jvm,
)

_PROCESSING_PIPELINE = processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = finalize,
)

def impl(ctx):
    """The rule implementation.

    Args:
      ctx: The context.

    Returns:
      A list of providers.
    """
    java_package = java.resolve_package_from_label(ctx.label, ctx.attr.custom_package)
    return processing_pipeline.run(ctx, java_package, _PROCESSING_PIPELINE)
