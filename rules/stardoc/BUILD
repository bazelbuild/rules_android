load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@stardoc//stardoc:stardoc.bzl", "stardoc")

bzl_library(
    name = "doc_rules",
    srcs = ["doc_rules.bzl"],
    deps = ["//rules:bzl"],
)

stardoc(
    name = "stardoc",
    out = "stardoc.md",
    input = "doc_rules.bzl",
    deps = [":doc_rules"],
)

build_test(
    name = "stardoc_build_test",
    targets = [":stardoc"],
)
