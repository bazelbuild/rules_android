load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(
    default_visibility =
        ["//:__subpackages__"],
)

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
)
