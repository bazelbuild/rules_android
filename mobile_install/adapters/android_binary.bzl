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
"""Rule adapter for android_binary."""

load(":adapters/base.bzl", "make_adapter")
load(":launcher.bzl", "make_launcher")
load(":launcher_direct.bzl", "make_direct_launcher")
load(":process.bzl", "process")
load(
    ":providers.bzl",
    "MIAndroidAarNativeLibsInfo",
    "MIAndroidAssetsInfo",
    "MIAndroidDexInfo",
    "MIAndroidResourcesInfo",
    "MIJavaResourcesInfo",
    "providers",
)
load(":resources.bzl", "get_assets_dir")
load(":transform.bzl", "dex", "filter_jars")
load(":utils.bzl", "utils")
load("//rules/flags:flags.bzl", "flags")

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return ["_android_sdk", "deps", "resources", "instruments"]

def extract(target, ctx):
    # extract is made visibile for testing
    """extract the rule and target data.

    Args:
      target: The target.
      ctx: The context.

    Returns:
      Input for process method
    """
    return dict(
        debug_key = utils.only(ctx.rule.files.debug_key, allow_empty = True),
        debug_signing_keys = ctx.rule.files.debug_signing_keys,
        debug_signing_lineage_file = utils.only(ctx.rule.files.debug_signing_lineage_file, allow_empty = True),
        key_rotation_min_sdk = ctx.rule.attr.key_rotation_min_sdk,
        merged_manifest = target[AndroidIdeInfo].generated_manifest,
        native_libs = target[AndroidIdeInfo].native_libs,
        package = target[AndroidIdeInfo].java_package,
        resource_apk = target[AndroidIdeInfo].resource_apk,
        resource_src_jar = target[AndroidIdeInfo].resource_jar.source_jar,  # This is the R with real ids.
        aar_native_libs_info = providers.make_mi_android_aar_native_libs_info(
            deps = providers.collect(
                MIAndroidAarNativeLibsInfo,
                ctx.rule.attr.deps,
            ),
        ),
        android_assets_info = providers.make_mi_android_assets_info(
            assets = depset(ctx.rule.files.assets),
            assets_dir = get_assets_dir(
                ctx.rule.files.assets[0],
                ctx.rule.attr.assets_dir,
            ) if ctx.rule.files.assets else None,
            deps = providers.collect(
                MIAndroidAssetsInfo,
                ctx.rule.attr.deps,
            ),
        ),
        android_dex_info = providers.make_mi_android_dex_info(
            dex_shards = dex(
                ctx,
                filter_jars(
                    ctx.label.name + "_resources.jar",
                    target[JavaInfo].runtime_output_jars,
                ) +
                (
                ),
                target[JavaInfo].transitive_deps,
            ),
            deps = providers.collect(MIAndroidDexInfo, ctx.rule.attr.deps),
        ),
        # TODO(djwhang): It wasteful to collect packages in
        # android_resources_info, rather we should be looking to pull them
        # from the resources_v3_info.
        android_resources_info = providers.make_mi_android_resources_info(
            package = target[AndroidIdeInfo].java_package,
            deps = providers.collect(
                MIAndroidResourcesInfo,
                ctx.rule.attr.deps,
            ),
        ),
        java_resources_info = providers.make_mi_java_resources_info(
            deps = providers.collect(
                MIJavaResourcesInfo,
                ctx.rule.attr.deps,
            ),
        ),
        android_jar = ctx.rule.attr._android_sdk[AndroidSdkInfo].android_jar,
        instrumented_app = ctx.rule.attr.instruments,
        apk = target.android.apk,
    )

def adapt(target, ctx):
    # adapt is made visibile for testing
    """Adapts the android rule

    Args:
        target: The target.
        ctx: The context.
    Returns:
         A list of providers
    """

    # launcher is created here to be used as the sibling everywhere else.
    launcher = utils.isolated_declare_file(ctx, ctx.label.name + "_mi/launcher")
    mi_app_info = process(ctx, sibling = launcher, **extract(target, ctx))

    if flags.get(ctx).use_direct_deploy:
        mi_app_launch_info = make_direct_launcher(
            ctx,
            mi_app_info,
            launcher,
            use_adb_root = flags.get(ctx).use_adb_root,
        )
    else:
        mi_app_launch_info = make_launcher(
            ctx,
            mi_app_info,
            launcher,
            use_adb_root = flags.get(ctx).use_adb_root,
        )

    return [
        mi_app_info,
        mi_app_launch_info,
        OutputGroupInfo(
            mobile_install_INTERNAL_ = depset(mi_app_launch_info.runfiles).to_list(),
            mobile_install_launcher_INTERNAL_ = [mi_app_launch_info.launcher],
        ),
    ]

android_binary = make_adapter(_aspect_attrs, adapt)
