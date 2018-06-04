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

"""Skylark rules for building Android apps."""
load(
    ":binary.bzl",
    _android_binary = "android_binary",
)
load(
    ":aar_import.bzl",
    _aar_import = "aar_import",
)
load(
    ":library.bzl",
    _android_library = "android_library",
)
load(
    ":local_test.bzl",
    _android_local_test = "android_local_test",
)
load(
    ":instrumentation_test.bzl",
    _android_instrumentation_test = "android_instrumentation_test",
)
load(
    ":device.bzl",
    _android_device = "android_device",
)
load(
    ":ndk_repository.bzl",
    _android_ndk_repository = "android_ndk_repository",
)
load(
    ":sdk_repository.bzl",
    _android_sdk_repository = "android_sdk_repository",
)

# Current version. Tools may check this to determine compatibility.
RULES_ANDROID_VERSION = "0.1.0"

android_binary = _android_binary

"""https://docs.bazel.build/versions/master/be/android.html#android_binary"""

aar_import = _aar_import

"""https://docs.bazel.build/versions/master/be/android.html#aar_import"""

android_library = _android_library

"""https://docs.bazel.build/versions/master/be/android.html#android_library"""

android_local_test = _android_local_test

"""https://docs.bazel.build/versions/master/be/android.html#android_local_test"""

android_instrumentation_test = _android_instrumentation_test

"""https://docs.bazel.build/versions/master/be/android.html#android_instrumentation_test"""

android_ndk_repository = _android_ndk_repository

"""https://docs.bazel.build/versions/master/be/android.html#android_ndk_repository"""

android_sdk_repository = _android_sdk_repository

"""https://docs.bazel.build/versions/master/be/android.html#android_sdk_repository"""

android_device = _android_device

"""https://docs.bazel.build/versions/master/be/android.html#android_device"""

