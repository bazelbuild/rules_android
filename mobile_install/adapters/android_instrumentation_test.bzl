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
"""Rule adapter for android_instrumentation_test."""

load(":adapters/base.bzl", "make_adapter")
load(":launcher.bzl", "make_launcher")
load(":launcher_direct.bzl", "make_direct_launcher")
load(":providers.bzl", "MIAppInfo")
load(":utils.bzl", "utils")
load("//rules/flags:flags.bzl", "flags")

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return ["test_app", "support_apps"]

def _adapt(target, ctx):
    is_mac = select({
        "//conditions:default": "no",
        "@platforms//os:macos": "yes",
    })
    if is_mac == "yes":
        fail("mobile-install does not support running tests on mac, check b/134172473 for more details")

    # TODO(b/): Tests have yet to be optimized so, this is an irrelevant error.
    # if flags.get(ctx).enable_splits:
    #     fail("mobile-install does not support running tests for split apks, check b/139762843 for more details! To run tests with mobile-install without splits, pass --define=enable_splits=False")

    launcher = utils.isolated_declare_file(ctx, ctx.label.name + "_mi/launcher")

    test_app = ctx.rule.attr.test_app

    # TODO(manalinandan): Re-enable direct deploy for test.
    # if _flags.get(ctx).use_direct_deploy:
    if False:
        mi_app_launch_info = make_direct_launcher(
            ctx,
            test_app[MIAppInfo],
            launcher,
            test_args = ctx.rule.attr.args,
            test_support_apps = ctx.rule.attr.support_apps,
            use_adb_root = flags.get(ctx).use_adb_root,
            is_test = True,
        )
    else:
        googplayservices_container_app = None
        test_support_apps = []
        for support_app in ctx.rule.attr.support_apps:
            # Checks if the support_apps is an android_binary rule and 'GoogPlayServices' is present in the label
            # This implies there is a GoogPlayServices container binary in the dependency
            if MIAppInfo in support_app and "GoogPlayServices" in str(support_app.label):
                googplayservices_container_app = support_app
            elif MIAppInfo in support_app:
                test_support_apps.append(support_app[MIAppInfo].apk)
        mi_app_launch_info = make_launcher(
            ctx,
            test_app[MIAppInfo],
            launcher,
            test_args = ctx.rule.attr.args,
            test_support_apks = test_support_apps,
            googplayservices_container_app = googplayservices_container_app,
            use_adb_root = flags.get(ctx).use_adb_root,
            is_test = True,
        )
    return [OutputGroupInfo(
        mobile_install_INTERNAL_ = depset(mi_app_launch_info.runfiles).to_list(),
        mobile_install_launcher_INTERNAL_ = [mi_app_launch_info.launcher],
    )]

android_instrumentation_test = make_adapter(_aspect_attrs, _adapt)
