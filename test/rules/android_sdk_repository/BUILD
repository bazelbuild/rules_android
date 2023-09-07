# Description:
#   Tests for android_sdk_repository.

load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "script_test",
)

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = [
        "//test:__subpackages__",
    ],
)

licenses(["notice"])

sh_library(
    name = "android_helper",
    testonly = True,
    srcs = ["android_helper.sh"],
    data = [
        "//rules/android_sdk_repository:bzl",
    ],
    visibility = ["//visibility:private"],
    deps = [
        "//test/bashunit",
        "@bazel_tools//tools/bash/runfiles",
    ],
)

sh_library(
    name = "test_lib",
    testonly = True,
    srcs = ["test_lib.sh"],
    visibility = ["//visibility:private"],
    deps = [
        ":android_helper",
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
        ":test_lib",
        "//test/bashunit",
        "@bazel_tools//tools/bash/runfiles",
    ],
)

script_test(
    name = "android_sdk_repository_platforms_test",
    srcs = ["android_sdk_repository_platforms_test.sh"],
    bazel_binaries = bazel_binaries,
    bazel_version = bazel_binaries.versions.current,
    deps = [
        ":test_lib",
        "//test/bashunit",
        "@bazel_tools//tools/bash/runfiles",
    ],
)

test_suite(
    name = "integration_tests",
    tests = [
        ":android_sdk_repository_platforms_test",
        ":android_sdk_repository_test",
    ],
)
