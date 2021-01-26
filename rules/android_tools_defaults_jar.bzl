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

"""Bazel rule for Android tools defaults jar."""

load(":attrs.bzl", "ANDROID_TOOLS_DEFAULTS_JAR_ATTRS")
load(":utils.bzl", "get_android_sdk")

def _impl(ctx):
    return [
        DefaultInfo(
            files = depset([get_android_sdk(ctx).android_jar]),
        ),
    ]

android_tools_defaults_jar = rule(
    attrs = ANDROID_TOOLS_DEFAULTS_JAR_ATTRS,
    implementation = _impl,
    fragments = ["android"],
    toolchains = ["@rules_android//toolchains/android_sdk:toolchain_type"],
)
