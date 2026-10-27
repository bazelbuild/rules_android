# Description:
#   Defines the Android SDK toolchain.

load("@platforms//host:constraints.bzl", "HOST_CONSTRAINTS")
load(":rule.bzl", "dummy_toolchain_dep")

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
    exec_compatible_with = HOST_CONSTRAINTS,
    # TODO(b/175833893): This causes the toolchain to not be selected, so
    # disable for now.
    #target_compatible_with = [
    #    "@bazel_tools//platforms:android",
    #],
    toolchain = "@androidsdk//:sdk",
    toolchain_type = ":toolchain_type",
)

dummy_toolchain_dep(
    name = "dummy_sdk_tools",
    sdk_toolchain = "@androidsdk//:sdk",
    visibility = ["//visibility:public"],
)
