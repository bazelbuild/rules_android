# The android_binary_internal rule.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//:__subpackages__"],
    deps = [
        "//rules:android_platforms_transition_bzl",
        "//rules:android_split_transition_bzl",
        "//rules:common_bzl",
    ],
)
