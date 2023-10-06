# Copyright 2021 The Bazel Authors. All rights reserved.
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

""" Bazel rules that test the Android Local Test rule.

launcher_test: Asserts that the executable is contained in the target's runfiles.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("@bazel_skylib//lib:sets.bzl", "sets")

def _android_local_test_default_launcher(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    expected_runfile = getattr(env.ctx.attr, "expected_runfile")

    runfiles = sets.make([f.short_path for f in target_under_test[DefaultInfo].default_runfiles.files.to_list()])
    asserts.true(env, sets.contains(runfiles, expected_runfile), "Expect runfiles to contains {0}".format(expected_runfile))

    return analysistest.end(env)

android_local_test_default_launcher_test = analysistest.make(
    _android_local_test_default_launcher,
    attrs = {
        "expected_runfile": attr.string(),
    },
)

def android_local_test_launcher_test_suite(name, expected_executable):
    android_local_test_default_launcher_test(
        name = "android_local_test_default_launcher",
        target_under_test = ":sample_test_default_launcher",
        expected_runfile = expected_executable,
    )

    native.test_suite(
        name = name,
        tests = [":android_local_test_default_launcher"],
    )
