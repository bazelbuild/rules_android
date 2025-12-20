# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""Tests for android_binary."""

load("@rules_cc//cc:defs.bzl", "CcToolchainConfigInfo")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(
    "//test/utils:lib.bzl",
    "analysistest",
)

visibility(PROJECT_VISIBILITY)

def _fake_cc_toolchain_config_impl(ctx):
    return cc_common.create_cc_toolchain_config_info(
        ctx = ctx,
        toolchain_identifier = "k8-toolchain",
        host_system_name = "local",
        target_system_name = "local",
        target_cpu = "k8",
        target_libc = "unknown",
        compiler = "clang",
        abi_version = "unknown",
        abi_libc_version = "unknown",
    )

fake_cc_toolchain_config = rule(
    implementation = _fake_cc_toolchain_config_impl,
    attrs = {},
    provides = [CcToolchainConfigInfo],
)

def multiple_android_platforms_test_impl(ctx):
    """Tests that android_binary successfully analyzes with
    multiple values in --android_platforms.

    Args:
        ctx: The ctx.

    Returns:
        The providers.
    """
    # This test only needs to run analysis on the android_binary
    # in target_under_test.
    env = analysistest.begin(ctx)
    return analysistest.end(env)

multiple_android_platforms_test = analysistest.make(
    impl = multiple_android_platforms_test_impl,
    config_settings = {
        # This makes the test toolchains available to the target under test.
        "//command_line_option:extra_toolchains": [
            "//test/rules/android_binary:fake_arm64-v8a_toolchain",
            "//test/rules/android_binary:fake_armeabi-v7a_toolchain",
        ],
        "//command_line_option:android_platforms": "@@//:arm64-v8a,@@//:armeabi-v7a",
    },
)
