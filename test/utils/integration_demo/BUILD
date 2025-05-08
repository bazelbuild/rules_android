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

script_test(
    name = "demo_test",
    srcs = ["demo_test.sh"],
    bazel_binaries = bazel_binaries,
    bazel_version = bazel_binaries.versions.current,
    # Disabled due to #368.
    tags = ["manual"],
    deps = [
        "//test/bashunit",
        "@bazel_tools//tools/bash/runfiles",
    ],
)

test_suite(
    name = "integration_tests",
    # Disabled due to #368.
    tags = ["manual"],
    tests = [
        ":demo_test",
    ],
)
