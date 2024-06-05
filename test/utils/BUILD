load("@rules_python//python:py_test.bzl", "py_test")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:private"],
)

licenses(["notice"])

exports_files(
    ["lib.bzl"],
    visibility = [
        "//test:__subpackages__",
    ],
)

filegroup(
    name = "testing",
    srcs = glob(["*"]),
    visibility = ["//test:__pkg__"],
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = [
        "//test:__subpackages__",
        "//tools/build_defs/android:__subpackages__",
    ],
    deps = [
        "//rules:visibility_bzl",
        "@rules_java//java:core_rules",
        "@bazel_skylib//lib:unittest",
    ],
)

py_test(
    name = "aar_native_libs_zip_creator_test",
    srcs = ["aar_native_libs_zip_creator_test.py"],
    deps = ["//tools/android:aar_native_libs_zip_creator"],
)

py_test(
    name = "aar_embedded_jars_extractor_test",
    srcs = ["aar_embedded_jars_extractor_test.py"],
    deps = ["//tools/android:aar_embedded_jars_extractor"],
)

py_test(
    name = "aar_embedded_proguard_extractor_test",
    srcs = ["aar_embedded_proguard_extractor_test.py"],
    deps = ["//tools/android:aar_embedded_proguard_extractor"],
)

py_test(
    name = "aar_resources_extractor_test",
    srcs = ["aar_resources_extractor_test.py"],
    deps = ["//tools/android:aar_resources_extractor"],
)
