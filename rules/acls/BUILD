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
    srcs = glob(["*.bzl"]),
    visibility = ["//:__subpackages__"],
)
