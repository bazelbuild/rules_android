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
This transition ensures that the platforms are set to valid Android Platforms.
"""

load("@bazel_skylib//lib:sets.bzl", "sets")
load(":min_sdk_version.bzl", "min_sdk_version")
load(":utils.bzl", "utils")

def _android_platforms_transition_impl(settings, attrs):
    if not bool(utils.get_cls(settings, "incompatible_enable_android_toolchain_resolution")):
        # Leave the configuration unchanged
        return {}

    new_settings = dict(settings)

    android_platforms = utils.get_cls(settings, "android_platforms")
    new_platforms = utils.get_cls(settings, "platforms")

    # Set the value of --platforms for this target and its dependencies.
    # 1. If --android_platforms is set, use a value from that.
    # 2. Otherwise, leave --platforms alone (this will probably lead to build errors).
    if android_platforms:
        # If the current value of --platforms is not one of the values of --android_platforms, change
        # it to be the first one. If the curent --platforms is part of --android_platforms, leave it
        # as-is.
        # NOTE: This does not handle aliases at all, so if someone is using aliases with platform
        # definitions this check will break.
        if not sets.is_subset(sets.make(new_platforms), sets.make(android_platforms)):
            new_platforms = [android_platforms[0]]

    # We only attempt this transition for rules that have the min_sdk_version attribute and set it explicitly
    if getattr(attrs, "min_sdk_version", 0):
        new_settings[min_sdk_version.SETTING] = min_sdk_version.clamp(getattr(attrs, "min_sdk_version", 0))
        # TODO(asinclair): How does the instruments case work? The two binaries need to use the same value.
        # If the setting is already set then we don't transition?

    new_settings[utils.add_cls_prefix("platforms")] = new_platforms
    return new_settings

android_platforms_transition = transition(
    implementation = _android_platforms_transition_impl,
    inputs = [
        "//command_line_option:android_platforms",
        "//command_line_option:platforms",
        "//command_line_option:incompatible_enable_android_toolchain_resolution",
        min_sdk_version.SETTING,
    ],
    outputs = [
        "//command_line_option:android_platforms",
        "//command_line_option:platforms",
        "//command_line_option:incompatible_enable_android_toolchain_resolution",
        min_sdk_version.SETTING,
    ],
)

testing = struct(
    impl = _android_platforms_transition_impl,
)
