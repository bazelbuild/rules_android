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

launcher_test: Asserts that the executable is populated correctly in the target script.
"""

def _android_local_test_launcher_integration(ctx):
    substitutions = {
        "%executable%": ctx.attr.target[DefaultInfo].files_to_run.executable.short_path,
        "%expected_executable%": ctx.attr.expected_executable,
    }
    runner = ctx.actions.declare_file(ctx.label.name + "_runner.sh")
    ctx.actions.expand_template(
        template = ctx.file._test_stub_script,
        substitutions = substitutions,
        output = runner,
    )
    return [
        DefaultInfo(
            executable = runner,
            runfiles = ctx.runfiles(
                files = [ctx.attr.target[DefaultInfo].files_to_run.executable],
            ),
        ),
    ]

integration_test = rule(
    attrs = dict(
        target = attr.label(),
        _test_stub_script = attr.label(
            cfg = "exec",
            default = ":integration_test_stub_script.sh",
            allow_single_file = True,
        ),
        expected_executable = attr.string(),
    ),
    test = True,
    implementation = _android_local_test_launcher_integration,
)

def android_local_test_launcher_integration_test_suite(name, expected_executable):
    integration_test(
        name = "android_local_test_default_launcher_integration",
        target = ":sample_test_default_launcher_integration",
        expected_executable = expected_executable,
    )

    native.test_suite(
        name = name,
        tests = [":android_local_test_default_launcher_integration"],
    )
