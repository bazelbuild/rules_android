# Tests that run on head android_local_test rule to verify Starlark resource processing pipeline.

load(
    "//rules:rules.bzl",
    "android_library",
    "android_local_test",
)
load(
    "//test/rules/android_local_test:test.bzl",
    "rule_test",
)

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:private"],
)

licenses(["notice"])

android_library(
    name = "resource_processing",
    assets = ["assets/bar.txt"],
    assets_dir = "assets",
    custom_package = "com.starlark_resources",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
)

# A custom package is necessary when an android_local_test is under a non-java directory.
android_local_test(
    name = "with_custom_package",
    srcs = ["SampleTest.java"],
    custom_package = "com.starlark_resources",
    manifest = "AndroidManifest.xml",
    test_class = "com.starlark_resources.SampleTest",
    deps = [
        ":resource_processing",
        "@robolectric//bazel:android-all",
        "@rules_android_maven//:androidx_test_core",
        "@rules_android_maven//:androidx_test_ext_junit",
        "@rules_android_maven//:junit_junit",
        "@rules_android_maven//:org_robolectric_robolectric",
    ],
)

rule_test(
    name = "with_custom_package_rule_test",
    target_under_test = ":with_custom_package",
)

# TODO(b/161359429): Create failure test for missing custom package under a non-java directory.
