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

"""Redirecting starlark rules to //rules/rules.bzl for easier migration to a new branch."""

load(
    "//rules/rules.bzl",
    _aar_import = "aar_import",
    _android_archive = "android_archive",
    _android_binary = "android_binary",
    _android_bundle_to_apks = "android_bundle_to_apks",
    _android_device = "android_device",
    _android_device_script_fixture = "android_device_script_fixture",
    _android_host_service_fixture = "android_host_service_fixture",
    _android_instrumentation_test = "android_instrumentation_test_macro",
    _android_library = "android_library_macro",
    _android_local_test = "android_local_test",
    _android_ndk_repository = "android_ndk_repository",
    _android_sdk = "android_sdk",
    _android_sdk_repository = "android_sdk_repository",
    _android_tools_defaults_jar = "android_tools_defaults_jar",
    _apk_import = "apk_import",
)

aar_import = _aar_import

android_archive = _android_archive

android_binary = _android_binary

android_bundle_to_apks = _android_bundle_to_apks

android_device = _android_device

android_device_script_fixture = _android_device_script_fixture

android_host_service_fixture = _android_host_service_fixture

android_instrumentation_test = _android_instrumentation_test

android_library = _android_library

android_local_test = _android_local_test

android_ndk_repository = _android_ndk_repository

android_sdk = _android_sdk

android_sdk_repository = _android_sdk_repository

android_tools_defaults_jar = _android_tools_defaults_jar

apk_import = _apk_import
