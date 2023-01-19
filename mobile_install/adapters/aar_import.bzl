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
"""Rule adapter for aar_import."""

load(":adapters/base.bzl", "make_adapter")
load(
    ":providers.bzl",
    "MIAndroidAarNativeLibsInfo",
    "MIAndroidAssetsInfo",
    "MIAndroidDexInfo",
    "MIAndroidResourcesInfo",
    "MIJavaResourcesInfo",
    "providers",
)
load(":resources.bzl", "liteparse")
load(":transform.bzl", "dex")
load("//rules:java.bzl", _java = "java")

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return ["deps", "exports"]

def _adapt(target, ctx):
    """Adapts the rule and target data.

    Args:
      target: The target.
      ctx: The context.

    Returns:
      A list of providers.
    """

    assets = depset()
    assets_dir = None
    if AndroidAssetsInfo in target:
        assets = target[AndroidAssetsInfo].assets
        assets_dir = target[AndroidAssetsInfo].local_asset_dir

    label = None
    resources = depset()
    if AndroidResourcesInfo in target:
        label = target[AndroidResourcesInfo].label
        resources = target[AndroidResourcesInfo].direct_android_resources

    return [
        providers.make_mi_android_aar_native_libs_info(
            native_libs = target[AndroidNativeLibsInfo].native_libs,
            deps = providers.collect(
                MIAndroidAarNativeLibsInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
            ),
        ),
        providers.make_mi_android_assets_info(
            assets = assets,
            assets_dir = assets_dir,
            deps = providers.collect(
                MIAndroidAssetsInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
            ),
        ),
        providers.make_mi_android_dex_info(
            dex_shards = dex(
                ctx,
                target[JavaInfo].runtime_output_jars,
                target[JavaInfo].transitive_deps,
            ),
            deps = providers.collect(
                MIAndroidDexInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
            ),
        ),
        providers.make_mi_android_resources_info(
            # TODO(b/124229660): The package for an aar should be retrieved from
            # the AndroidManifest.xml in the aar. Using the package is a short
            # term work-around.
            package = _java.resolve_package_from_label(
                ctx.label,
                ctx.rule.attr.package,
            ),
            label = label,
            r_pb = liteparse(ctx),
            resources = resources,
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
            ),
        ),
    ]

aar_import = make_adapter(_aspect_attrs, _adapt)
