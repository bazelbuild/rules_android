# Description:
#   The android_sdk_repository repository rule for using an Android SDK with Bazel.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(
    default_applicable_licenses = ["//:license"],
)

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//rules:__pkg__"]
)

bzl_library(
    name = "bzl",
    srcs = [
        "empty.template.bzl",
        "helper.bzl",
        "rule.bzl",
        "template.bzl",
    ],
    visibility = ["//:__subpackages__"],
    deps = [
        "//rules:android_revision_bzl",
    ],
)
