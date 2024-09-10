load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

bzl_library(
    name = "providers_bzl",
    srcs = [
        "providers.bzl",
        "reexport_providers.bzl",
    ],
    visibility = ["//:__subpackages__"],
    deps = ["//rules:visibility_bzl"],
)
