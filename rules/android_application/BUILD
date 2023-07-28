# The android_application rule.

load("@rules_python//python:defs.bzl", "py_binary")
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
        "//rules:common_bzl",
        "//rules/flags:bzl",
    ],
)

py_binary(
    name = "merge_feature_manifests",
    srcs = ["merge_feature_manifests.py"],
    python_version = "PY3",
    visibility = ["//visibility:public"],
    deps = [
        "@py_absl//absl:app",
        "@py_absl//absl/flags",
    ],
)

filegroup(
    name = "merge_feature_manifests.par",
    srcs = [":merge_feature_manifests"],
    output_group = "python_zip_file",
    visibility = ["//visibility:public"],
)
