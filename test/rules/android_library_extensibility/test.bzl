# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Tests for the extensibility functionality of android_library."""

load(
    "//test/utils:lib.bzl",
    "asserts",
    "unittest",
)
load(
    ":custom_android_library.bzl",
    "CustomProviderInfo",
)

def custom_android_library_test_impl(ctx):
    env = unittest.begin(ctx)

    # Assert that the custom provider exists
    asserts.true(env, CustomProviderInfo in ctx.attr.lib)
    asserts.equals(env, ctx.attr.lib[CustomProviderInfo].key, "test_key")

    return unittest.end(env)

custom_android_library_test = unittest.make(
    impl = custom_android_library_test_impl,
    attrs = {
        "lib": attr.label(providers = [CustomProviderInfo]),
    },
)
