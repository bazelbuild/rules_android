# Android Sandboxed SDK rules.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

exports_files([
    "android_sandboxed_sdk.bzl",
    "android_sandboxed_sdk_bundle.bzl",
])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//:__subpackages__"],
    deps = [
        "//rules:common_bzl",
        "//rules/android_binary:bzl",
    ],
)
