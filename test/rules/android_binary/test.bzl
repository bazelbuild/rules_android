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
load(
    "//rules:utils.bzl",
    _utils = "utils",
    _utils_testing = "testing",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(
    "//test/utils:lib.bzl",
    "analysistest",
    "asserts",
    "unittest",
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
        "//command_line_option:android_platforms": [
            "@@//:arm64-v8a",
            "@@//:armeabi-v7a",
        ],
    },
)

def _dummy():
    pass

def _has_multi_split_test_impl(ctx):
    env = unittest.begin(ctx)

    # In older Bazel versions (e.g. Bazel 7), dir(ctx.split_attr) includes built-in
    # methods like to_json and to_proto. Non-dict attributes or methods must not be
    # evaluated with len() directly.
    fake_ctx_single_split = struct(
        split_attr = struct(
            deps = {"x86": []},
            data = None,
            non_dict_attr = _dummy,
        ),
    )
    asserts.false(env, _utils_testing.has_multi_split(fake_ctx_single_split))

    fake_ctx_multi_split = struct(
        split_attr = struct(
            deps = {"x86": [], "arm64-v8a": []},
        ),
    )
    asserts.true(env, _utils_testing.has_multi_split(fake_ctx_multi_split))

    fake_ctx_no_split = struct(
        split_attr = None,
    )
    asserts.false(env, _utils_testing.has_multi_split(fake_ctx_no_split))

    # _get_primary_split must safely fall back when queried attribute
    # matches a non-dict value on split_attr or is not split.
    fake_ctx_primary = struct(
        fragments = struct(platform = struct(platform = None)),
        split_attr = struct(
            deps = {"x86": ["dep1"]},
            non_split = "foo",
        ),
        attr = struct(
            deps = ["dep_attr"],
            non_split = "foo",
        ),
    )
    asserts.equals(env, [], _utils.get_primary_split(fake_ctx_primary, "unknown_attr", default = []))
    asserts.equals(env, ["dep1"], _utils.get_primary_split(fake_ctx_primary, "deps", default = []))
    asserts.equals(env, "foo", _utils.get_primary_split(fake_ctx_primary, "non_split", default = "default"))

    return unittest.end(env)

has_multi_split_test = unittest.make(
    impl = _has_multi_split_test_impl,
)
