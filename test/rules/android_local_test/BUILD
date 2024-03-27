load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("//rules:rules.bzl", "android_local_test")
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

config_setting(
    name = "jdk17_macos",
    constraint_values = [
        "@platforms//os:macos",
        "@platforms//cpu:x86_64",
    ],
    values = {
        "java_runtime_version": "17",
    },
)

config_setting(
    name = "jdk17_macos_aarch64",
    constraint_values = [
        "@platforms//os:macos",
        "@platforms//cpu:aarch64",
    ],
    values = {
        "java_runtime_version": "17",
    },
)

config_setting(
    name = "jdk17_linux",
    constraint_values = ["@platforms//os:linux"],
    values = {
        "java_runtime_version": "17",
    },
)

android_local_test_launcher_test_suite(
    name = "android_local_test_launcher_tests",
    expected_executable = select({
        ":jdk17_linux": "../remotejdk17_linux/bin/java",
        ":jdk17_macos": "../remotejdk17_macos/bin/java",
        ":jdk17_macos_aarch64": "../remotejdk17_macos_aarch64/bin/java",
        "//conditions:default": "../local_jdk/bin/java",
    }),
    tags = ["manual"],
)

android_local_test_launcher_integration_test_suite(
    name = "android_local_test_launcher_integration_tests",
    expected_executable = select({
        ":jdk17_linux": "external/remotejdk17_linux/bin/java",
        ":jdk17_macos": "external/remotejdk17_macos/bin/java",
        ":jdk17_macos_aarch64": "external/remotejdk17_macos_aarch64/bin/java",
        "//conditions:default": "../local_jdk/bin/java",
    }),
    tags = ["manual"],
)
