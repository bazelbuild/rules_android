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
"""
This module adds no-op repository rules when the Android SDK is not installed.
"""

package(default_visibility = ["//visibility:public"])

# android_sdk_repository was used without a valid Android SDK being set.
# Either the path attribute of android_sdk_repository or the ANDROID_HOME
# environment variable must be set.
# This is a minimal BUILD file to allow non-Android builds to continue.

alias(
    name = "has_androidsdk",
    actual = "@bazel_tools//tools/android:always_false",
)

filegroup(
    name = "files",
    srcs = [":error_message"],
)

filegroup(
    name = "sdk",
    srcs = [":error_message"],
)

filegroup(
    name = "d8_jar_import",
    srcs = [":error_message"],
)

filegroup(
    name = "dx_jar_import",
    srcs = [":error_message"],
)

genrule(
    name = "invalid_android_sdk_repository_error",
    outs = [
        "error_message",
    ],
    cmd = """echo \
    android_sdk_repository was used without a valid Android SDK being set. \
    Either the path attribute of android_sdk_repository or the ANDROID_HOME \
    environment variable must be set. ; \
    exit 1 """,
)
