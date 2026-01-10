load(
    ":helper.bzl",
    "create_android_sdk_rules",
    "create_system_images_filegroups",
)

package(default_visibility = ["//visibility:public"])

# The toolchain type used to distinguish Android SDK toolchains.
toolchain_type(name = "sdk_toolchain_type")

config_feature_flag(
    name = "true",
    allowed_values = [
        "true",
        "false",
    ],
    default_value = "true",
)

config_setting(
    name = "always_true",
    flag_values = {
        ":true": "true",
    },
)

config_setting(
    name = "always_false",
    flag_values = {
        ":true": "false",
    },
)

config_setting(
    name = "darwin_arm64",
    constraint_values = [
        "@platforms//os:macos",
        "@platforms//cpu:arm64",
    ],
    visibility = ["//visibility:public"],
)

config_setting(
    name = "darwin_x86_64",
    constraint_values = [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
    ],
    visibility = ["//visibility:public"],
)

alias(
    name = "has_androidsdk",
    actual = ":always_true",
)

create_android_sdk_rules(
    name = "__repository_name__",
    build_tools_version = "__build_tools_version__",
    build_tools_directory = "__build_tools_directory__",
    api_levels = [__api_levels__],
    default_api_level = __default_api_level__,
    exec_compatible_with = [__exec_compatible_with__],
)

alias(
    name = "adb",
    actual = "platform-tools/adb",
)

alias(
    name = "dexdump",
    actual = "build-tools/%s/dexdump" % "__build_tools_directory__",
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
        ":darwin_x86_64": ["emulator/qemu/darwin-x86_64/qemu-system-i386"],
        ":darwin_arm64": ["emulator/qemu/darwin-aarch64/qemu-system-aarch64"],
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
