# Description:
#   Tests for android_sdk_repository.

load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "script_test",
)

licenses(["notice"])

sh_library(
    name = "android_helper",
    testonly = True,
    srcs = ["android_helper.sh"],
    data = [
        "//rules:android_sdk_repository_bzl",
    ],
    deps = [
        "//test/bashunit",
        "@bazel_tools//tools/bash/runfiles",
    ],
)

script_test(
    name = "android_sdk_repository_test",
    srcs = ["android_sdk_repository_test.sh"],
    bazel_binaries = bazel_binaries,
    bazel_version = bazel_binaries.versions.current,
    deps = [
        ":android_helper",
        "//test/bashunit",
        "@bazel_tools//tools/bash/runfiles",
    ],
)
