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
"""Special bzl file for generating Stardoc from specific rules.

Some of the top-level rules in rule.bzl are actually macros,
so generating Stardoc from the rules.bzl files will not generate
the actual docs for the rule. These symbols point to the actual
underlying rules with documented attributes. See //rules:stardoc.
"""

load(
    "//rules/aar_import:rule.bzl",
    _aar_import = "aar_import",
)
load(
    "//rules/android_application:android_application_rule.bzl",
    _android_application = "android_application",
)
load(
    "//rules/android_binary:rule.bzl",
    _android_binary = "android_binary",
)
load(
    "//rules/android_library:rule.bzl",
    _android_library = "android_library",
)
load(
    "//rules/android_local_test:rule.bzl",
    _android_local_test = "android_local_test",
)
load(
    "//rules/android_sdk_repository:rule.bzl",
    _android_sdk_repository = "android_sdk_repository",
)

aar_import = _aar_import
android_application = _android_application
android_binary = _android_binary
android_library = _android_library
android_local_test = _android_local_test
android_sdk_repository = _android_sdk_repository
