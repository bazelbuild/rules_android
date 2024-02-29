load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_python//python:py_test.bzl", "py_test")
load(":test.bzl", "r8_neverlink_deps_test")

py_test(
    name = "r8_integration_test",
    srcs = ["r8_integration_test.py"],
    args = ["$(location @androidsdk//:dexdump)"],
    data = [
        "//test/rules/android_binary_internal/r8_integration/java/com/basicapp:basic_app_R8_no_shrink",
        "//test/rules/android_binary_internal/r8_integration/java/com/basicapp:basic_app_R8_shrink",
        "//test/rules/android_binary_internal/r8_integration/java/com/basicapp:basic_app_no_R8",
        "@androidsdk//:dexdump",
    ],
)

r8_neverlink_deps_test(
    name = "r8_neverlink_deps_test",
    target_under_test = "//test/rules/android_binary_internal/r8_integration/java/com/neverlink:android_binary_internal_with_neverlink_deps",
)

build_test(
    name = "android_binary_with_neverlink_deps_build_test",
    targets = ["//test/rules/android_binary_internal/r8_integration/java/com/neverlink:android_binary_with_neverlink_deps"],
)
