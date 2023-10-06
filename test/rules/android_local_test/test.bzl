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

"""Bazel rules that test the Android Local Test rule.

rule_test: Inspect and assert on rule providers.
"""

load("//rules:providers.bzl", "AndroidFilteredJdepsInfo")
load("//test/utils:asserts.bzl", "asserts")

VALIDATION = "_validation"

def _rule_test_impl(ctx):
    # Assert on expected providers
    if not JavaInfo in ctx.attr.target_under_test:
        fail("Missing JavaInfo provider")
    if not AndroidFilteredJdepsInfo in ctx.attr.target_under_test:
        fail("Missing AndroidFilteredJdepsInfo provider")

    # Collecting validation outputs from deps
    transitive_validation_outputs = []
    for dep in ctx.attr.deps:
        if hasattr(dep[OutputGroupInfo], VALIDATION):
            transitive_validation_outputs.append(dep[OutputGroupInfo]._validation)

    output_group_info = dict(ctx.attr.expected_output_group_info)
    if VALIDATION in output_group_info:
        output_group_info[VALIDATION] = (
            output_group_info[VALIDATION] +
            [f.basename for f in depset(transitive = transitive_validation_outputs).to_list()]
        )
    asserts.provider.output_group_info(
        output_group_info,
        ctx.attr.target_under_test[OutputGroupInfo],
    )

    # Create test script to assert on provider contents
    args = dict(
        jdeps_print_tool = ctx.executable._jdeps_print_tool.short_path,
        jdeps = ctx.attr.target_under_test[JavaInfo].outputs.jdeps.short_path,
        filtered_jdeps = ctx.attr.target_under_test[AndroidFilteredJdepsInfo].jdeps.short_path,
        res_jar = ctx.attr.target_under_test.label.name + "_resources.jar",
        expect_resources = str(ctx.attr.expect_resources),
    )
    test_script = ctx.actions.declare_file("%s_script.sh" % ctx.label.name)
    ctx.actions.write(
        test_script,
        """
jdeps=`{jdeps_print_tool} --in {jdeps} | sed 's#_migrated/##g'`
filtered_jdeps=`{jdeps_print_tool} --in {filtered_jdeps} | sed 's#_migrated/##g'`

entries=`echo "$jdeps" | wc -l`
matches=`echo "$jdeps" | grep '{res_jar}' | wc -l`
filtered_entries=`echo "$filtered_jdeps" | wc -l`
filtered_matches=`echo "$filtered_jdeps" | grep '{res_jar}' | wc -l`

expected_matches=1
expected_filtering_differences=1
if [ {expect_resources} == "False" ]; then
  expected_matches=0
  expected_filtering_differences=0
fi

if [ $matches -ne $expected_matches ]; then
  echo "Expected one resource.jar in jdeps"
  exit 1
elif [ $filtered_matches -ne 0 ]; then
  echo "Expected no resource.jar in filtered jdeps"
  exit 1
elif [ $(($entries-$filtered_entries)) -ne $expected_filtering_differences ]; then
  echo "Expected to remove one item when filtering"
  exit 1
fi
""".format(**args),
        is_executable = True,
    )
    return [
        DefaultInfo(
            runfiles = ctx.runfiles(
                files = [
                    test_script,
                    ctx.executable._jdeps_print_tool,
                    ctx.attr.target_under_test[JavaInfo].outputs.jdeps,
                    ctx.attr.target_under_test[AndroidFilteredJdepsInfo].jdeps,
                ],
            ),
            executable = test_script,
        ),
    ]

rule_test = rule(
    attrs = dict(
        asserts.provider.attrs.items(),
        expect_resources = attr.bool(default = True),
        target_under_test = attr.label(),
        deps = attr.label_list(),
        _jdeps_print_tool = attr.label(
            cfg = "exec",
            default = "//src/tools/jdeps:print_jdeps",
            executable = True,
        ),
    ),
    implementation = _rule_test_impl,
    test = True,
)
