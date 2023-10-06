load("//rules:rules.bzl", "android_local_test")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
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
    name = "jdk17",
    values = {
        "java_runtime_version": "17",
    },
)

android_local_test_launcher_test_suite(
    name = "android_local_test_launcher_tests",
    expected_executable = select({
        ":jdk17": "../remotejdk17_linux/bin/java",
        "//conditions:default": "third_party/java/jdk/jdk-sts-k8/bin/java",
    }),
)

android_local_test_launcher_integration_test_suite(
    name = "android_local_test_launcher_integration_tests",
    expected_executable = select({
        ":jdk17": "rules_android/../remotejdk17_linux/bin/java",
        "//conditions:default": "rules_android/third_party/java/jdk/jdk-sts-k8/bin/java",
    }),
)
