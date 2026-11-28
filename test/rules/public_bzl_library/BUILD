# Description:
#   Tests that the bzl_library targets documentation tools depend on are public.

load("@bazel_skylib//rules:build_test.bzl", "build_test")

package(default_applicable_licenses = ["//:license"])

licenses(["notice"])

# This package is not in the visibility list of any bzl_library, so it only
# builds when the targets below are public.
build_test(
    name = "public_bzl_library_test",
    targets = [
        "//android:bzl",
        "//rules:bzl",
    ],
)
