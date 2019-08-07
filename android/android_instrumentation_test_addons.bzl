# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Bazel specific addons for android_instrumentation_test."""

def optimize_apks(ctx, apk_infos):
    apks = []
    for apk_info in apk_infos:
        apks.append(apk_info.signed_apk)
    return apks

def should_optimize_apks(ctx):
    return False

def get_test_runner(ctx):
    return struct(
        test_suite_property_name = "bazel.test_suite=com.google.android.apps.common.testing.suite.AndroidDeviceTestSuite",
        test_entry_point = struct(
            target = ctx.attr._test_entry_point,
            executable = ctx.executable._test_entry_point,
        ),
    )

ADDON_ATTRS = dict(
    _aapt = attr.label(
        cfg = "host",
        executable = True,
        default = "@androidsdk//:aapt_binary",
    ),
    _adb = attr.label(
        cfg = "host",
        allow_single_file = True,
        default = "@androidsdk//:adb",
        executable = True,
    ),
    _remote_jdk_linux = attr.label(
        default = Label("@bazel_tools//tools/jdk:remote_jdk11"),
    ),
    _remote_java_tools_linux = attr.label(
        default = Label("@remote_java_tools_linux//:Runner"),
    ),
)

def get_addon_targets(ctx):
    return [
        ctx.attr._remote_java_tools_linux,
        ctx.attr._remote_jdk_linux,
        ctx.attr._aapt,
    ]

def get_addon_substitutions(ctx):
    workspace = "${TEST_SRCDIR}/%s" % ctx.workspace_name
    return {
        "%aapt%": "%s/%s" % (workspace, ctx.attr._aapt.files_to_run.executable.short_path),
        "%adb%": "%s/%s" % (workspace, ctx.attr._adb.files_to_run.executable.short_path),
    }
