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

"""Skylark rules for building Android apps."""

load(
    "//rules/aar_import:rule.bzl",
    _aar_import = "aar_import",
)

#load(
#    ":apk_import.bzl",
#    _apk_import = "apk_import",
#)

load(
    ":android_binary.bzl",
    _android_binary = "android_binary",
)

# load(
#     ":android_device.bzl",
#     _android_device = "android_device",
# )
# load(
#     ":android_device_script_fixture.bzl",
#     _android_device_script_fixture = "android_device_script_fixture",
# )
# load(
#     ":android_host_service_fixture.bzl",
#     _android_host_service_fixture = "android_host_service_fixture",
# )
# load(
#     ":android_instrumentation_test.bzl",
#     _android_instrumentation_test = "android_instrumentation_test",
# )

load(
    "//rules/android_library:rule.bzl",
    _android_library = "android_library_macro",
)

# load(
#     ":android_local_test.bzl",
#     _android_local_test = "android_local_test",
# )

load(
    ":android_ndk_repository.bzl",
    _android_ndk_repository = "android_ndk_repository",
)
load(
    ":android_sdk.bzl",
    _android_sdk = "android_sdk",
)
load(
    ":android_sdk_repository.bzl",
    _android_sdk_repository = "android_sdk_repository",
)
load(
    ":android_tools_defaults_jar.bzl",
    _android_tools_defaults_jar = "android_tools_defaults_jar",
)

# Current version. Tools may check this to determine compatibility.
RULES_ANDROID_VERSION = "0.1.0"

aar_import = _aar_import

"""https://docs.bazel.build/versions/master/be/android.html#android_apk_to_bundle"""

android_binary = _android_binary

"""https://docs.bazel.build/versions/master/be/android.html#android_binary"""

#android_device = _android_device

"""https://docs.bazel.build/versions/master/be/android.html#android_device"""

#android_device_script_fixture = _android_device_script_fixture

"""https://docs.bazel.build/versions/master/be/android.html#android_host_service_fixture"""

#android_host_service_fixture = _android_host_service_fixture

"""https://docs.bazel.build/versions/master/be/android.html#android_device_script_fixture"""

#android_instrumentation_test = _android_instrumentation_test

"""https://docs.bazel.build/versions/master/be/android.html#android_instrumentation_test"""

android_library = _android_library

"""https://docs.bazel.build/versions/master/be/android.html#android_library"""

#android_local_test = _android_local_test

"""https://docs.bazel.build/versions/master/be/android.html#android_local_test"""

android_ndk_repository = _android_ndk_repository

"""https://docs.bazel.build/versions/master/be/android.html#android_ndk_repository"""

android_sdk = _android_sdk

"""https://docs.bazel.build/versions/master/be/android.html#android_sdk"""

android_sdk_repository = _android_sdk_repository

"""https://docs.bazel.build/versions/master/be/android.html#android_sdk_repository"""

android_tools_defaults_jar = _android_tools_defaults_jar

"""https://docs.bazel.build/versions/master/be/android.html#android_tools_defaults_jar"""

#apk_import = _apk_import
#
#"""https://docs.bazel.build/versions/master/be/android.html#apk_import"""
