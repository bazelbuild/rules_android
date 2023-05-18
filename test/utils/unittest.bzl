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

"""Bazel lib that provides test helpers for testing."""

load(":file.bzl", _file = "file")
load(
    "@bazel_skylib//lib:unittest.bzl",
    _analysistest = "analysistest",
    _unittest = "unittest",
)

TestInfo = provider(
    doc = "Provides a test a suggested set of attributes.",
    fields = {
        "name": "The name of the test.",
        "prefix": "The prefix used to isolate artifact and target names.",
    },
)

def _prefix(prefix, name):
    """Prepends the given prefix to the given name."""
    return "%s-%s" % (prefix, name)

def _prefix_from_test_info(test_info, name):
    """Prepends the prefix of a TestInfo to the given name."""
    return _prefix(test_info.prefix, name)

def _test_suite(
        name = None,
        test_scenarios = None):
    """Creates a test suite containing the list of test targets.

    Args:
      name: Name of the test suite, also used as part of a prefix for naming.
      test_scenarios: A list of methods, that setup and the test. Each scenario
        method should accept a TestInfo provider.
    """
    test_targets = []
    for scenario_name, make_scenario in test_scenarios.items():
        test_prefix = _prefix(name, scenario_name)
        test_info = TestInfo(
            prefix = test_prefix,
            name = test_prefix + "_test",
        )
        make_scenario(test_info)
        test_targets.append(test_info.name)

    native.test_suite(
        name = name,
        tests = test_targets,
    )

def _fake_java_library(name):
    class_name = "".join(
        [part.title() for part in name.replace("-", "_").split("_")],
    )
    native.java_library(
        name = name,
        srcs = [_file.create(
            class_name + ".java",
            contents = """@SuppressWarnings("DefaultPackage")
class %s{}""" % class_name,
        )],
    )

def _fake_jar(name):
    if not name.endswith(".jar"):
        fail("fake_jar method requires name to end with '.jar'")
    _fake_java_library(name[:-4])
    return name

def _fake_executable(name):
    return _file.create(name, contents = "echo %s" % name, executable = True)

def _analysis_test_error(message, *args):
    return [
        AnalysisTestResultInfo(
            success = False,
            message = message % args,
        ),
    ]

analysistest = _analysistest

unittest = struct(
    # Forward through unittest methods through the current unittest.
    analysis_test_error = _analysis_test_error,
    begin = _unittest.begin,
    end = _unittest.end,
    fake_executable = _fake_executable,
    fake_jar = _fake_jar,
    fake_java_library = _fake_java_library,
    make = _unittest.make,
    prefix = _prefix_from_test_info,
    test_suite = _test_suite,
)
