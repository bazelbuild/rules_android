# Starlark Resource Packaging for Android Rules.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(
    default_visibility =
        ["//third_party/bazel_rules/rules_android"],
)

licenses(["notice"])

exports_files(["rule.bzl"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    deps = [
        "@rules_android//rules:common_bzl",
    ],
)
