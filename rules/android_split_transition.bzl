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
- When `--incompatible_enable_android_toolchain_resolution` is set:
    - `--android_platforms`
      - Split using the values of this flag as the target platform
      - If this is unset, use the first value from `--platforms`.
        - If this isn't a valid Android platform, an error will be thrown
          during the build.
- Fall back to legacy flag logic:
    - `--fat_apk_cpus`
      - Split using the values of this flag as `--cpu`
      - If this is unset, fall though.
    - `--android_cpu`
      - Don't split, just use the value of this flag as `--cpu`
      - This will not update the output path to include "-android".
      - If this is unset, fall though.
    - Default
      - This will not update the output path to include "-android".
      - Don't split, using the same previously set `--cpu` value.

"""

load(":utils.bzl", "utils")

def _android_split_transition_impl(settings, __):
    if utils.get_cls(settings, "incompatible_enable_android_toolchain_resolution"):
        # Always use `--android_platforms` when toolchain resolution is enabled.
        platforms_to_split = utils.get_cls(settings, "android_platforms")
        if not platforms_to_split:
            # If `--android_platforms` is unset, instead use only the first
            # value from `--platforms`.
            target_platform = utils.only(utils.get_cls(settings, "platforms"))
            platforms_to_split = [target_platform]
        return _handle_android_platforms(settings, platforms_to_split)

    # Fall back to the legacy flags.

    if utils.get_cls(settings, "fat_apk_cpu"):
        return _handle_fat_apk_cpus(settings)

    if (utils.get_cls(settings, "android_cpu") and
        utils.get_cls(settings, "android_crosstool_top") and
        utils.get_cls(settings, "android_crosstool_top") != utils.get_cls(settings, "crosstool_top")):
        return _handle_android_cpu(settings)

    return _handle_default_split(settings, utils.get_cls(settings, "cpu"))

def _non_split_cpus(new_split_options, name, settings):
    if not utils.get_cls(settings, "fat_apk_hwasan") or not name.contains("arm64-v8a"):
        return

    # A HWASAN build is different from a regular one in these ways:
    # - The native library install directory gets a "-hwasan" suffix
    # - Some compiler/linker command line options are different (defined in
    #   the Android C++ toolchain)
    # - The name of the output directory is changed so that HWASAN and
    #   non-HWASAN artifacts do not conflict
    new_settings = dict(settings)
    new_settings.update({
        utils.add_cls_prefix("cc_output_directory_tag"): "hwasan",
        utils.add_cls_prefix("android hwasan"): True,
    })
    new_split_options[name + "-hwasan"] = new_settings

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
        split_options[utils.add_cls_prefix("fat_apk_cpu")] = []
        split_options[utils.add_cls_prefix("android_platforms")] = []

        # The cpu flag will be set by platform mapping if a mapping exists.
        split_options[utils.add_cls_prefix("platforms")] = [platform]
        _cc_flags_from_android(settings, split_options)

        result[name] = split_options
        _non_split_cpus(result, name, settings)
    return result

def _handle_default_split(settings, cpu):
    """ Returns a single-split transition that uses the `--cpu`

    This does not change any flags.
    """
    result = dict()
    result[cpu] = dict(settings)
    _non_split_cpus(result, cpu, settings)
    return result

def _handle_android_cpu(settings):
    """ Returns a transition that sets `--cpu` to the value of `--android_cpu`

    This also sets other C++ flags based on the corresponding Android flags.
    """
    android_cpu = settings[utils.add_cls_prefix("android_cpu")]
    split_options = dict(settings)
    split_options[utils.add_cls_prefix("cpu")] = android_cpu
    _cc_flags_from_android(settings, split_options)

    # Ensure platforms aren't set so that platform mapping can take place.
    split_options[utils.add_cls_prefix("platforms")] = []

    # Because configuration is based on cpu flags we need to disable C++ toolchain resolution
    return _handle_default_split(split_options, android_cpu)

def _handle_fat_apk_cpus(settings):
    """ Returns a multi-split transition that sets `--cpu` with the values of `--fat_apk_cpu`

    Also sets other C++ flags based on the corresponding Android flags.
    """
    result = dict()
    for cpu in sorted(utils.get_cls(settings, "fat_apk_cpu")):
        split_options = dict(settings)

        # Disable fat APKs for the child configurations.
        split_options[utils.add_cls_prefix("fat_apk_cpu")] = []
        split_options[utils.add_cls_prefix("android_platforms")] = []

        # Set the cpu & android_cpu.
        # TODO(bazel-team): --android_cpu doesn't follow --cpu right now; it should.
        split_options[utils.add_cls_prefix("android_cpu")] = cpu
        split_options[utils.add_cls_prefix("cpu")] = cpu
        _cc_flags_from_android(settings, split_options)

        # Ensure platforms aren't set so that platform mapping can take place.
        split_options[utils.add_cls_prefix("platforms")] = []

        result[cpu] = split_options
        _non_split_cpus(result, cpu, split_options)

    return result

def _cc_flags_from_android(settings, new_settings):
    new_settings[utils.add_cls_prefix("compiler")] = utils.get_cls(settings, "android_compiler")
    new_settings[utils.add_cls_prefix("grte_top")] = utils.get_cls(settings, "android_grte_top")
    new_settings[utils.add_cls_prefix("dynamic_mode")] = utils.get_cls(settings, "android_dynamic_mode")

    android_crosstool_top = utils.get_cls(settings, "android_crosstool_top")
    if android_crosstool_top:
        new_settings[utils.add_cls_prefix("crosstool_top")] = android_crosstool_top

    new_settings[utils.add_cls_prefix("Android configuration distinguisher")] = "android"

android_split_transition = transition(
    implementation = _android_split_transition_impl,
    inputs = [
        "//command_line_option:Android configuration distinguisher",
        "//command_line_option:android hwasan",
        "//command_line_option:cc_output_directory_tag",
        "//command_line_option:android_compiler",
        "//command_line_option:android_cpu",
        "//command_line_option:android_crosstool_top",
        "//command_line_option:android_dynamic_mode",
        "//command_line_option:android_grte_top",
        "//command_line_option:android_platforms",
        "//command_line_option:compiler",
        "//command_line_option:cpu",
        "//command_line_option:crosstool_top",
        "//command_line_option:dynamic_mode",
        "//command_line_option:grte_top",
        "//command_line_option:fat_apk_cpu",
        "//command_line_option:fat_apk_hwasan",
        "//command_line_option:incompatible_enable_android_toolchain_resolution",
        "//command_line_option:platforms",
    ],
    outputs = [
        "//command_line_option:Android configuration distinguisher",
        "//command_line_option:android hwasan",
        "//command_line_option:cc_output_directory_tag",
        "//command_line_option:android_compiler",
        "//command_line_option:android_cpu",
        "//command_line_option:android_crosstool_top",
        "//command_line_option:android_dynamic_mode",
        "//command_line_option:android_grte_top",
        "//command_line_option:android_platforms",
        "//command_line_option:compiler",
        "//command_line_option:cpu",
        "//command_line_option:crosstool_top",
        "//command_line_option:dynamic_mode",
        "//command_line_option:grte_top",
        "//command_line_option:fat_apk_cpu",
        "//command_line_option:fat_apk_hwasan",
        "//command_line_option:incompatible_enable_android_toolchain_resolution",
        "//command_line_option:platforms",
    ],
)
