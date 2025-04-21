# The aar_import rule.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(
    default_applicable_licenses = ["//:license"],
)

exports_files(["rule.bzl"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//rules:__pkg__"]
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//rules:__pkg__"],
    deps = [
        "//rules:common_bzl",
        "//rules/flags:bzl",
        "@rules_java//java/common",
    ],
)
