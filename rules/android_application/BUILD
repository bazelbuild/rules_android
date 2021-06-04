# The android_application rule.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

exports_files([
    "bundle_deploy.sh_template",
    "feature_module_validation.sh",
    "gen_android_feature_manifest.sh",
    "gen_priority_android_feature_manifest.sh",
    "rule.bzl",
])

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
