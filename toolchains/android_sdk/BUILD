# Description:
#   Defines the Android SDK toolchain.

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

# Android SDK Toolchain Type
toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "android_sdk_tools",
    # This causes the toolchain to not be selected under arm, so
    # disable for now.
    # To be refined as part of https://github.com/bazelbuild/rules_android/issues/72
    #exec_compatible_with = [
    #    "@platforms//cpu:x86_64",
    #    "@platforms//os:linux",
    #],
    # TODO(b/175833893): This causes the toolchain to not be selected, so
    # disable for now.
    #target_compatible_with = [
    #    "@bazel_tools//platforms:android",
    #],
    toolchain = "@androidsdk//:sdk",
    toolchain_type = ":toolchain_type",
)
