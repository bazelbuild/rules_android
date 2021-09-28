# Flags for Android rules and mobile-install

load("@rules_android//rules/flags:flags.bzl", "flags")
load("@rules_android//rules/flags:flag_defs.bzl", "define_flags")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")


licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
)

define_flags()

flags.FLAGS()
