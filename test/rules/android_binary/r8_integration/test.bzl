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
"""Tests for R8 integration."""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(
    "//test/utils:lib.bzl",
    "analysistest",
    "asserts",
)

visibility(PROJECT_VISIBILITY)

def r8_neverlink_deps_test_impl(ctx):
    """Tests that the correct neverlink libs are added to the R8 invocation.

    Args:
        ctx: The ctx.

    Returns:
        The providers.
    """

    env = analysistest.begin(ctx)

    actions = {a.mnemonic: a for a in analysistest.target_actions(env)}
    r8_action = actions.get("AndroidR8", None)
    if not r8_action:
        analysistest.fail("R8 action not found")

    # Check that 3 jars are specified to R8 through --lib: the android jar + 2 neverlink libs
    lib_files = []
    for i in range(len(r8_action.argv)):
        arg = r8_action.argv[i]
        if arg == "--lib":
            lib_files.append(r8_action.argv[i + 1])

    asserts.equals(env, 3, len(lib_files))
    asserts.true(env, lib_files[1].endswith("libneverlink_lib1.jar"))
    asserts.true(env, lib_files[2].endswith("libneverlink_lib2.jar"))

    return analysistest.end(env)

r8_neverlink_deps_test = analysistest.make(
    impl = r8_neverlink_deps_test_impl,
)
