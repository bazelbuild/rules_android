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
"""Tests for android_application."""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(
    "//test/utils:lib.bzl",
    "analysistest",
    "asserts",
)

visibility(PROJECT_VISIBILITY)

def _key_rotation_test_impl(ctx):
    """Tests that a lineage file produces a keystore.properties for the oldest key.

    Args:
        ctx: The ctx.

    Returns:
        The providers.
    """
    env = analysistest.begin(ctx)
    actions = [
        a
        for a in analysistest.target_actions(env)
        if a.mnemonic == "FileWrite" and a.outputs.to_list()[0].basename == "keystore.properties"
    ]
    asserts.equals(env, 1, len(actions))
    content = actions[0].content
    asserts.true(env, "ks=" in content, "missing ks= in:\n" + content)
    asserts.true(env, "bazel-out" not in content, "unexpected bazel-out in:\n" + content)
    asserts.true(env, "ks-key-alias=androiddebugkey" in content)
    return analysistest.end(env)

key_rotation_test = analysistest.make(impl = _key_rotation_test_impl)
