load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//:__pkg__"],
)

bzl_library(
    name = "providers_bzl",
    srcs = [
        "providers.bzl",
    ],
    visibility = ["//visibility:public"],
    deps = ["//rules:visibility_bzl"],
)
