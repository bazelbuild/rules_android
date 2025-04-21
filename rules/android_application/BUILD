# The android_application rule.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_python//python:defs.bzl", "py_binary")

package(
    default_applicable_licenses = ["//:license"],
)

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
    visibility = ["//rules:__pkg__"]
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//rules:__pkg__"],
    deps = [
        "//rules:android_platforms_transition_bzl",
        "//rules:common_bzl",
        "//rules/android_sandboxed_sdk:bzl",
        "//rules/flags:bzl",
        "@rules_java//java/common",
    ],
)

py_binary(
    name = "merge_feature_manifests",
    srcs = ["merge_feature_manifests.py"],
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
