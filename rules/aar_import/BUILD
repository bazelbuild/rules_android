# The aar_import rule.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

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
        "@rules_android//rules/flags:bzl",
    ],
)
