load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//rules:rules.bzl", "android_local_test")
load(":coverage_test.bzl", "coverage_test_suite")
load(":java_launcher_integration_test.bzl", "android_local_test_launcher_integration_test_suite")
load(":java_launcher_test.bzl", "android_local_test_launcher_test_suite")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

exports_files([
    "EmptyTest.java",
    "integration_test_stub_script.sh",
])

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//visibility:private"],
    deps = [
        "//rules:common_bzl",
        "//rules:visibility_bzl",
        "//rules/android_local_test:bzl",
        "@bazel_skylib//lib:unittest",
        "@rules_java//java/common",
    ],
)

coverage_test_suite(
    name = "coverage_tests",
)

android_local_test(
    name = "sample_test_default_launcher",
    srcs = ["EmptyTest.java"],
    custom_package = "com.google.android.emptytest",
    test_class = "com.google.android.emptytest.EmptyTest",
    deps = [
        "@robolectric//bazel:android-all",
        "@rules_android_maven//:androidx_test_ext_junit",
        "@rules_android_maven//:junit_junit",
    ],
)

android_local_test(
    name = "sample_test_default_launcher_integration",
    srcs = ["EmptyTest.java"],
    custom_package = "com.google.android.emptytest",
    test_class = "com.google.android.emptytest.EmptyTest",
    deps = [
        "@robolectric//bazel:android-all",
        "@rules_android_maven//:androidx_test_ext_junit",
        "@rules_android_maven//:junit_junit",
    ],
)

android_local_test_launcher_test_suite(
    name = "android_local_test_launcher_tests",
    tags = ["manual"],
)

android_local_test_launcher_integration_test_suite(
    name = "android_local_test_launcher_integration_tests",
    tags = ["manual"],
)
