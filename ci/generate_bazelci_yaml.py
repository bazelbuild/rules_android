# Copyright 2025 The Bazel Authors. All rights reserved.
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
"""Automatically generates the BazelCI Yaml file for rules_android.

This program's development is inspired by recent changes to new toolchain
configuration requirements in upstream transitive dependencies (notably 
protobuf) that require maintaining an overly-verbose bazelci yaml file.

To add a new task:
1. Create a new BazelCiTask in the BazelCiYmlWriterConstants class.
2. Add the task to the task list in BazelCiYmlWriter.tasks_unexpanded.
"""

import argparse
import copy
import itertools


class BazelCiYmlWriterConstants:
    """Constants for BazelCI configuration writing."""
    def __init__(self):
        # Note: 'bzlmod' is not a matrix variable supported by BazelCI intrinsically,
        # but this program provides some syntactic sugar for it.
        self.SUPPORTED_MATRIX_VARS = set([
            "bazel",
            "platform",
            "bzlmod",
        ])
        self.DEFAULT_MATRIX = dict({
            "bazel": [
                "7.4.1",
                "8.2.1",
                # "last_green", # TODO: Re-enable last_green once protobuf and grpc dep issues are resolved.
            ],
            "platform": [
                "ubuntu2004",
                "macos",
                "macos_arm64",
                # "windows", # TODO: Fix windows tests.
            ],
            "bzlmod": ["enabled", "disabled"],
        })
        # Temporary workaround to Windows issues: define a separate matrix just for Windows.
        self.WINDOWS_MATRIX = dict({
            "bazel": ["7.4.1", "8.2.1", "last_green"],
            "platform": [
                "windows", # TODO: Fix windows tests.
            ],
            "bzlmod": ["enabled", "disabled"],
        })
    
        self.tools_task = BazelCiTask(
            job_name = "tools",
            display_name = "Tools",
            build_targets = [
                "//android/...",
                "//src/...",
                "-//src/java/com/example/sampleapp/...",
                "//test/...",
                "-//test/rules/...", # Tested in `rules`
                "//toolchains/...",
                "//tools/...",
                "-//tools/android/...", # TODO(#122): Un-exclude this once #122 is fixed.
            ],
            test_targets = [
                "//src/...",
                "-//src/java/com/example/sampleapp/...",
                "//test/...",
                "-//test/rules/...",
            ],
            build_flags = [],
            test_flags = [],
        )
        self.rules_task = BazelCiTask(
            job_name = "rules",
            display_name = "Rules",
            build_targets = [
                "//rules/...",
            ],
            test_targets = [
                "//test/rules/...",
                # Resource processor tests need an extra flag for now,
                # due to legacy compatibility reasons.
                "-//test/rules/resources/..."
            ],
            build_flags = [],
            test_flags = [],
        )
        self.resource_rules_task = BazelCiTask(
            job_name = "resource_rules",
            display_name = "Resource Rules",
            build_targets = [
                "//test/rules/resources/...",
            ],
            test_targets = [
                "//test/rules/resources/...",
            ],
            build_flags = [
                "--//rules/flags:manifest_merge_order=legacy",
            ],
            test_flags = [
                "--//rules/flags:manifest_merge_order=legacy",
            ],
        )
        self.coverage_task = BazelCiTask(
            job_name = "android_local_test_coverage",
            display_name = "Android_Local_Test Coverage",
            coverage_targets = [
                "//test/rules/android_local_test/java/com/...",
            ],
        )
        self.basic_app_task = BazelCiTask(
            job_name = "basic_app",
            display_name = "Basic App",
            working_directory = "examples/basicapp",
            build_targets = [
                "//java/com/basicapp:basic_app",
            ],
            test_targets = [],
            build_flags = [],
            test_flags = [],
        )

class BazelCiYmlWriter:
    """Entrypoint class for BazelCI yml writing logic."""
    def __init__(self, matrix : dict = {}):
        _constants = BazelCiYmlWriterConstants()
        if matrix:
            self.matrix = matrix
        else:
            self.matrix = _constants.DEFAULT_MATRIX

        # Add new tasks here
        self.tasks_unexpanded = [
            _constants.tools_task,
            _constants.rules_task,
            # _constants.resource_rules_task, # TODO(#397): These tests don't seem to work well with Mac for some reason.
            _constants.coverage_task,
            _constants.basic_app_task,
        ]
        self.tasks = []
        self.cartesian_product = []

    def write(self, path, mode = 'w', write_header = True):
        with open(path, mode) as f:
            if write_header:
                f.write("# DO NOT MODIFY: This is autogenerated by rules_android/ci/generate_bazelci_yaml.py.\n")
                f.write("tasks:\n")
            for task in self.tasks:
                f.write(str(task) + "\n")

    def expand_tasks(self):
        self.cartesian_product = self.matrix_cartesian_product()
        for base_task in self.tasks_unexpanded:
            for combo in self.cartesian_product:
                # Handle configuration-specific details here
                task = copy.deepcopy(base_task)
                for key in sorted(combo.keys()):
                    value = combo[key]
                    sanitized_value = value.replace(".", "_")
                    task.job_name += f"_{key}_{sanitized_value}"
                    task.display_name += f" w/ {key} {value}"
                    # This if/else block implements per-attribute custom behavior.
                    if key == "bzlmod":
                        bzlmod_flags = []
                        if value == "enabled":
                            bzlmod_flags = [
                                "--enable_bzlmod",
                                "--noenable_workspace",
                            ]
                        elif value == "disabled":
                            bzlmod_flags = [
                                "--noenable_bzlmod",
                                "--enable_workspace",
                            ]
                        # Only add the bzlmod flags to *_flags attrs if *_tests is defined.
                        if task.build_targets:
                            task.build_flags.extend(bzlmod_flags)
                        if task.test_targets:
                            task.test_flags.extend(bzlmod_flags)
                        if task.coverage_targets:
                            task.coverage_flags.extend(bzlmod_flags)
                    elif key == "platform":
                        task.platform = value
                        platform_mapping = dict({
                            "ubuntu2004": "linux",
                            "macos": "mac",
                            "macos_arm64": "mac",
                        })
                        if value in platform_mapping:
                            value = platform_mapping[value]
                        if task.build_targets:
                            task.build_flags.append(f"--config={value}")
                        if task.test_targets:
                            task.test_flags.append(f"--config={value}")
                        if task.coverage_targets:
                            task.coverage_flags.append(f"--config={value}")
                    else:
                        # Default behavior: Just assign the attr directly to the task object.
                        setattr(task, key, value)
                self.tasks.append(task)
                            
    def matrix_cartesian_product(self):
        """Generates a Cartesian product of all of the matrix dimensions."""
        matrix_ = []
        for key in sorted(self.matrix.keys()):
            l = []
            for value in sorted(self.matrix[key]):
                l.append((key, value))
            matrix_.append(l)

        cartesian = []
        for combo in itertools.product(*matrix_):
            d = dict()
            for tup in combo:
                key = tup[0]
                value = tup[1]
                d[key] = value
            cartesian.append(d)

        return cartesian

class BazelCiTask():
    """Basic container task for BazelCI tasks."""
    def __init__(self, job_name: str, display_name: str, build_targets: list[str] = [], 
                 test_targets: list[str] = [], build_flags: list[str] = [], 
                 test_flags: list[str] = [], coverage_targets: list[str] =  [],
                 coverage_flags: list[str] = [], platform: str = "", bazel: str = "",
                 working_directory: str = ""):
        self.job_name = job_name
        self.display_name = display_name
        self.build_targets = build_targets
        self.test_targets = test_targets
        self.build_flags = build_flags
        self.test_flags = test_flags
        self.coverage_targets = coverage_targets
        self.coverage_flags = coverage_flags
        self.platform = platform
        self.bazel = bazel
        self.working_directory = working_directory
        self._buf = ""

    def write(self, s: str):
        self._buf += s

    def writeln(self, s: str):
        self.write(s + "\n")

    def writeattr(self, attr_name: str):
        attr_value = getattr(self, attr_name)
        if not attr_value:
            return
        self.write(f"    {attr_name}:")
        if isinstance(attr_value, str):
            self.writeln(f" {attr_value}")
        elif isinstance(attr_value, list):
            # Add a newline after `attr_name:`
            self.writeln("")
            for item in attr_value:
                self.writeln(f"      - \"{item}\"")

    def __str__(self):
        self.writeln(f"  {self.job_name}:")
        self.writeln(f"    name: \"{self.display_name}\"")
        self.writeln(f"    platform: {self.platform}")
        self.writeln(f"    bazel: {self.bazel}")
        self.writeattr("working_directory")
        self.writeattr("build_targets")
        self.writeattr("build_flags")
        self.writeattr("test_targets")
        self.writeattr("test_flags")
        self.writeattr("coverage_targets")
        self.writeattr("coverage_flags")
        return self._buf


def write_bazelci_yml(path: str):
    # Write the default matrix: all test/builds/apps with mac and linux
    writer = BazelCiYmlWriter()
    writer.expand_tasks()
    writer.write(path)

    # Write the Windows matrix: just basic app with bzlmod on/off
    constants = BazelCiYmlWriterConstants()
    windows_writer = BazelCiYmlWriter(matrix = constants.WINDOWS_MATRIX)
    windows_writer.tasks_unexpanded = [
        constants.basic_app_task,
    ]
    windows_writer.expand_tasks()
    windows_writer.write(path, mode = "a", write_header = False)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--yml_output", required = False, 
                        default = ".bazelci/presubmit.yml",
                        help = "The path to the output yml file.")

    args = parser.parse_args()

    write_bazelci_yml(args.yml_output)

if __name__ == "__main__":
    main()