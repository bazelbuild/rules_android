# Description:
#   Defines the Android toolchain.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load(":toolchain.bzl", "android_toolchain")

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

# Android Toolchain Type
toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
)

# Default Android Toolchain
android_toolchain(
    name = "android_default",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "android_default_toolchain",
    toolchain = ":android_default",
    toolchain_type = ":toolchain_type",
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
)

_ZIPPER = "@bazel_tools//third_party/ijar:zipper"

alias(
    name = "zip",
    actual = _ZIPPER,
    visibility = ["//visibility:public"],
)

alias(
    name = "unzip",
    actual = _ZIPPER,
    visibility = ["//visibility:public"],
)
