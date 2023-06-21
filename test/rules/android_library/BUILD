load(":custom_android_library.bzl", "custom_android_library")
load(":test.bzl", "custom_android_library_test")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

licenses(["notice"])

custom_android_library(
    name = "custom_android_library",
    testonly = True,
    key = "test_key",
)

custom_android_library_test(
    name = "custom_android_library_test",
    lib = ":custom_android_library",
)

test_suite(
    name = "integration_tests",
    tests = [
        ":custom_android_library_test",
    ],
)
