# Copyright 2022 The Bazel Authors. All rights reserved.
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
Defines the Android Split configuration transition for properly handling native
dependencies

The intended order of checks is:
- If `--android_platforms` is set:
  - Split using the values of this flag as the target platform
  - If this is unset, use the first value from `--platforms`.
    - If this isn't a valid Android platform, an error will be thrown
      during the build.
- Default
  - This will not update the output path to include "-android".
  - Don't split, using the same previously set `--cpu` value.

"""

load(":utils.bzl", "utils")

def _android_split_transition_impl(settings, _):
    # Always use `--android_platforms` when toolchain resolution is enabled.
    platforms_to_split = utils.get_cls(settings, "android_platforms")
    if not platforms_to_split:
        # If `--android_platforms` is unset, instead use only the first
        # value from `--platforms`.
        target_platform = utils.only(utils.get_cls(settings, "platforms"))
        platforms_to_split = [target_platform]
    return _handle_android_platforms(settings, platforms_to_split)

# This transition exists so targets can be built in the same configuration as the deps of android_binary.
# The goal is to avoid unnecessarily building a dependency in two different configurations which wastes resources.
def _android_transition_impl(settings, attr):
    # There are cases where an android_binary depends on another android_binary via an attribute
    # we apply this transition to. In that case we end up applying this transition twice.
    # The second transition will fail. Since the transition clears out --android_platforms we can
    # use that as a signal to do nothing.
    if not utils.get_cls(settings, "android_platforms"):
        return None

    configs = _android_split_transition_impl(settings, attr)

    # Always pick the config based on the first value in --android_platforms
    # This ensures the choice is consistent with the android_platforms_transition
    return configs[utils.get_cls(settings, "android_platforms")[0].name]

def _handle_android_platforms(settings, platforms_to_split):
    """
    Splits the configuration based on the values of --android_platforms.

    Each split will set the --platforms flag to one value from
    --android_platforms, as well as clean up a few other flags around native
    CC builds.
    """
    result = dict()
    for platform in platforms_to_split:
        name = platform.name
        split_options = dict(settings)

        # Disable fat APKs for the child configurations.
        split_options[utils.add_cls_prefix("android_platforms")] = []

        # The cpu flag will be set by platform mapping if a mapping exists.
        split_options[utils.add_cls_prefix("platforms")] = [platform]
        _cc_flags_from_android(settings, split_options)

        result[name] = split_options
    return result

def _cc_flags_from_android(settings, new_settings):
    new_settings[utils.add_cls_prefix("compiler")] = utils.get_cls(settings, "android_compiler")
    new_settings[utils.add_cls_prefix("dynamic_mode")] = utils.get_cls(settings, "android_dynamic_mode")

    new_settings[utils.add_cls_prefix("Android configuration distinguisher")] = "android"

_INPUTS = [
    "//command_line_option:Android configuration distinguisher",
    "//command_line_option:android_compiler",
    "//command_line_option:android_dynamic_mode",
    "//command_line_option:android_platforms",
    "//command_line_option:compiler",
    "//command_line_option:dynamic_mode",
    "//command_line_option:platforms",
]

_OUTPUTS = [
    "//command_line_option:Android configuration distinguisher",
    "//command_line_option:android_compiler",
    "//command_line_option:android_dynamic_mode",
    "//command_line_option:android_platforms",
    "//command_line_option:compiler",
    "//command_line_option:dynamic_mode",
    "//command_line_option:platforms",
]
android_split_transition = transition(
    implementation = _android_split_transition_impl,
    inputs = _INPUTS,
    outputs = _OUTPUTS,
)

android_transition = transition(
    implementation = _android_transition_impl,
    inputs = _INPUTS,
    outputs = _OUTPUTS,
)
