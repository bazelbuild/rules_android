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
This module contains repository rules and helpers needed to configure the Android SDK for Bazel.
"""

load(
    ":helper.bzl",
    "create_android_sdk_rules",
    "create_system_images_filegroups",
)

package(default_visibility = ["//visibility:public"])

alias(
    name = "has_androidsdk",
    actual = "@bazel_tools//tools/android:always_true",
)

create_android_sdk_rules(
    name = "__repository_name__",
    build_tools_version = "__build_tools_version__",
    build_tools_directory = "__build_tools_directory__",
    api_levels = [__api_levels__],
    default_api_level = __default_api_level__,
)

alias(
    name = "adb",
    actual = "platform-tools/adb",
)

alias(
    name = "emulator",
    actual = "emulator/emulator",
)

# emulator v29+ removed the arm and x86 specific binaries.
# Keeping these aliases around for backwards compatibility.
alias(
    name = "emulator_arm",
    actual = "emulator/emulator",
)

alias(
    name = "emulator_x86",
    actual = "emulator/emulator",
)

filegroup(
    name = "emulator_x86_bios",
    srcs = glob(
        ["emulator/lib/pc-bios/*"],
        allow_empty = True,
    ),
)

alias(
    name = "mksd",
    actual = "emulator/mksdcard",
)

filegroup(
    name = "emulator_shared_libs",
    srcs = glob(
        ["emulator/lib64/**"],
        allow_empty = True,
    ),
)

filegroup(
    name = "sdk_path",
    srcs = ["."],
)

filegroup(
    name = "qemu2_x86",
    srcs = ["emulator/emulator"] + select({
        "@bazel_tools//src/conditions:darwin_x86_64": ["emulator/qemu/darwin-x86_64/qemu-system-i386"],
        "@bazel_tools//src/conditions:darwin_arm64": ["emulator/qemu/darwin-aarch64/qemu-system-aarch64"],
        "//conditions:default": ["emulator/qemu/linux-x86_64/qemu-system-i386"],
    }),
)

create_system_images_filegroups(
    system_image_dirs = [__system_image_dirs__],
)

exports_files(
    # TODO(katre): implement these.
    #[ __exported_files__] +
    glob(["system-images/**"], allow_empty = True),
)
