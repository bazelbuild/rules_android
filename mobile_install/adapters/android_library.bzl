# Copyright 2018 The Bazel Authors. All rights reserved.
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
"""Rule adapter for android_library."""

load(":adapters/base.bzl", "make_adapter")
load(
    ":providers.bzl",
    "MIAndroidAarNativeLibsInfo",
    "MIAndroidAssetsInfo",
    "MIAndroidDexInfo",
    "MIAndroidResourcesInfo",
    "MIAndroidSdkInfo",
    "MIJavaResourcesInfo",
    "providers",
)
load(":resources.bzl", "get_assets_dir")
load(":transform.bzl", "dex", "filter_jars")

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return [
        "_android_sdk",
        # Access the kt toolchain to get kotlin std and runtime libs.
        "_toolchain",
        "deps",
        "exports",
    ]

def _adapt(target, ctx):
    """Adapts the rule and target data.

    Args:
      target: The target.
      ctx: The context.

    Returns:
      A list of providers.
    """
    kt_toolchain = [ctx.rule.attr._toolchain] if hasattr(ctx.rule.attr, "_toolchain") else []
    if ctx.rule.attr.neverlink:
        return []

    if target[AndroidIdeInfo].idl_generated_java_files:
        aidl_lib = [ctx.rule.attr._android_sdk[MIAndroidSdkInfo].aidl_lib]
    else:
        aidl_lib = []

    return [
        providers.make_mi_android_aar_native_libs_info(
            deps = providers.collect(
                MIAndroidAarNativeLibsInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
            ),
        ),
        providers.make_mi_android_assets_info(
            assets = depset(ctx.rule.files.assets),
            assets_dir = get_assets_dir(
                ctx.rule.files.assets[0],
                ctx.rule.attr.assets_dir,
            ) if ctx.rule.files.assets else None,
            deps = providers.collect(
                MIAndroidAssetsInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
            ),
        ),
        providers.make_mi_android_dex_info(
            dex_shards = dex(
                ctx,
                filter_jars(
                    ctx.label.name + "_resources.jar",
                    target[JavaInfo].runtime_output_jars,
                ),
                target[JavaInfo].transitive_deps,
            ),
            deps = providers.collect(
                MIAndroidDexInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
                aidl_lib,
                kt_toolchain,
            ),
        ),
        providers.make_mi_android_resources_info(
            package = target[AndroidIdeInfo].java_package,
            deps = providers.collect(
                MIAndroidResourcesInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
            ),
        ),
        providers.make_mi_java_resources_info(
            deps = providers.collect(
                MIJavaResourcesInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
                aidl_lib,
                kt_toolchain,
            ),
        ),
    ]

android_library = make_adapter(_aspect_attrs, _adapt)
