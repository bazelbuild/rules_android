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
"""Configuration definitions."""

load("@bazel_skylib//rules:common_settings.bzl", "int_setting")

def configurations(name = "configurations"):
    # Configuration setting for propagating an android_binary's min_sdk_version to its transitive
    # dependencies.
    int_setting(
        name = "min_sdk_version",
        build_setting_default = 0,
        visibility = [
            "//mobile_install:__subpackages__",
            "//rules:__subpackages__",
            "//test:__subpackages__",
            "//third_party/java_src/desugar_jdk_libs:__subpackages__",
            # Visibility so that release mi can depend on the released version of this file
            # We do not expect released mi to depend on this head target, though
            "//tools/android/mi/bin/release:__subpackages__",
            "//tools/android/mi/testing:__subpackages__",
        ],
    )
