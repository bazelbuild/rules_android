# The android_library rule.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility =
        ["//:__subpackages__"],
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
        "//rules:common_bzl",
        "//rules/flags:bzl",
        "@bazel_skylib//rules:common_settings",
    ],
)
