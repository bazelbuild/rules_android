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

load(
    "//mobile_install:providers.bzl",
    "MIAndroidAssetsInfo",
    "MIAndroidDexInfo",
    "MIAndroidResourcesInfo",
    "MIJavaResourcesInfo",
    "providers",
)
load("//mobile_install:resources.bzl", "liteparse")
load("//mobile_install:transform.bzl", "dex")
load("//rules:java.bzl", _java = "java")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("//rules:providers.bzl", "StarlarkAndroidResourcesInfo")
load(":base.bzl", "make_adapter")

def _handle_starlark_android_resources(target, ctx):
    inner_mi_assets = []
    inner_mi_android_resources = []
    for node in target[StarlarkAndroidResourcesInfo].direct_resources_nodes.to_list():
        inner_mi_android_resources.append(
            providers.make_mi_android_resources_info(
                package = node.manifest,
                label = node.label,
                r_pb = liteparse(ctx),
                resources = node.resource_files,
                deps = providers.collect(
                    MIAndroidResourcesInfo,
                    ctx.rule.attr.deps,
                    ctx.rule.attr.exports,
                ),
            ),
        )
        inner_mi_assets.append(
            providers.make_mi_android_assets_info(
                assets = node.assets,
                assets_dir = node.assets_dir,
                deps = providers.collect(
                    MIAndroidAssetsInfo,
                    ctx.rule.attr.deps,
                    ctx.rule.attr.exports,
                ),
            ),
        )

    return [
        providers.make_mi_android_assets_info(
            deps = inner_mi_assets,
        ),
        providers.make_mi_android_resources_info(
            deps = inner_mi_android_resources,
        ),
    ]

def _handle_native(target, ctx):
    assets = depset()
    assets_dir = None
    if AndroidAssetsInfo in target:
        assets = target[AndroidAssetsInfo].assets
        assets_dir = target[AndroidAssetsInfo].local_asset_dir

    label = None
    resources = depset()
    manifest = None
    if AndroidResourcesInfo in target:
        label = target[AndroidResourcesInfo].label
        resources = target[AndroidResourcesInfo].direct_android_resources
        manifest = target[AndroidResourcesInfo].manifest

    return [
        providers.make_mi_android_assets_info(
            assets = assets,
            assets_dir = assets_dir,
            deps = providers.collect(
                MIAndroidAssetsInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
            ),
        ),
        providers.make_mi_android_resources_info(
            package = manifest,
            label = label,
            r_pb = liteparse(ctx),
            resources = resources,
            deps = providers.collect(
                MIAndroidResourcesInfo,
                ctx.rule.attr.deps,
                ctx.rule.attr.exports,
            ),
        ),
    ]

def _get_android_resources_and_assets(target, ctx):
    if StarlarkAndroidResourcesInfo in target:
        return _handle_starlark_android_resources(target, ctx)
    else:
        return _handle_native(target, ctx)

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

    return _get_android_resources_and_assets(target, ctx) + [
        providers.make_mi_android_dex_info(
            dex_shards = dex(
                ctx,
                target[JavaInfo].runtime_output_jars,
                target[JavaInfo].transitive_compile_time_jars,
            ),
            deps = providers.collect(
                MIAndroidDexInfo,
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
