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

load("@rules_android//rules:acls.bzl", "acls")
load("@rules_android//rules:java.bzl", "java")
load(
    "@rules_android//rules:processing_pipeline.bzl",
    "ProviderInfo",
    "processing_pipeline",
)
load("@rules_android//rules:resources.bzl", _resources = "resources")
load("@rules_android//rules:utils.bzl", "compilation_mode", "get_android_toolchain", "utils")

def _process_resources(ctx, java_package, **unused_ctxs):
    packaged_resources_ctx = _resources.package(
        ctx,
        assets = ctx.files.assets,
        assets_dir = ctx.attr.assets_dir,
        resource_files = ctx.files.resource_files,
        manifest = ctx.file.manifest,
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
        deps = ctx.attr.deps,
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

# Order dependent, as providers will not be available to downstream processors
# that may depend on the provider. Iteration order for a dictionary is based on
# insertion.
PROCESSORS = dict(
    ResourceProcessor = _process_resources,
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
