# Description:
#   Tests for android_sdk_repository.

load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "script_test",
)
load("@rules_shell//shell:sh_library.bzl", "sh_library")

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
        "//rules:bzl",
    ],
    visibility = ["//visibility:private"],
    deps = [
        "//test/bashunit",
        "@rules_shell//shell/runfiles",
    ],
)

script_test(
    name = "android_sdk_repository_test",
    srcs = ["android_sdk_repository_test.sh"],
    bazel_binaries = bazel_binaries,
    bazel_version = bazel_binaries.versions.current,
    # TODO(b/372950743): Fix the rules_shell integration with this test.
    tags = ["manual"],
    deps = [
        ":android_helper",
        "//test/bashunit",
        "@rules_shell//shell/runfiles",
    ],
)

test_suite(
    name = "integration_tests",
    # TODO(b/372950743): Fix the rules_shell integration with this test.
    tags = ["manual"],
    tests = [
        ":android_sdk_repository_test",
    ],
)
