# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Starlark rules for building Android apps."""

# Don't use relative paths since this file is coppied to //android/rules.bzl.

load(
    "//rules/aar_import:rule.bzl",
    _aar_import = "aar_import",
)
load(
    "//rules/android_application:android_application.bzl",
    _android_application = "android_application",
)
load(
    "//rules:android_binary.bzl",
    _android_binary = "android_binary",
)
load(
    "//rules/android_library:rule.bzl",
    _android_library = "android_library_macro",
)
load(
    "//rules/android_local_test:rule.bzl",
    _android_local_test = "android_local_test",
)
load(
    "//rules:android_ndk_repository.bzl",
    _android_ndk_repository = "android_ndk_repository",
)
load(
    "//rules/android_sandboxed_sdk:android_sandboxed_sdk.bzl",
    _android_sandboxed_sdk = "android_sandboxed_sdk",
)
load(
    "//rules/android_sandboxed_sdk:android_sandboxed_sdk_bundle.bzl",
    _android_sandboxed_sdk_bundle = "android_sandboxed_sdk_bundle",
)
load(
    "//rules:android_sdk.bzl",
    _android_sdk = "android_sdk",
)
load(
    "//rules/android_sdk_repository:rule.bzl",
    _android_sdk_repository = "android_sdk_repository",
)
load(
    "//rules:android_tools_defaults_jar.bzl",
    _android_tools_defaults_jar = "android_tools_defaults_jar",
)
load(
    "//rules/android_sandboxed_sdk:asar_import.bzl",
    _asar_import = "asar_import",
)

# Current version. Tools may check this to determine compatibility.
RULES_ANDROID_VERSION = "0.1.0"

aar_import = _aar_import
android_application = _android_application
android_binary = _android_binary
android_library = _android_library
android_local_test = _android_local_test
android_ndk_repository = _android_ndk_repository
android_sandboxed_sdk = _android_sandboxed_sdk
android_sandboxed_sdk_bundle = _android_sandboxed_sdk_bundle
android_sdk = _android_sdk
android_sdk_repository = _android_sdk_repository
android_tools_defaults_jar = _android_tools_defaults_jar
asar_import = _asar_import
