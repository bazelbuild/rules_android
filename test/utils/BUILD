load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_python//python:defs.bzl", "py_test")

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
        "@rules_java//java:core_rules",
        "@bazel_skylib//lib:unittest",
    ],
)

[
    py_test(
        name = tool + "_test",
        srcs = [tool + "_test.py"],
        deps = ["//tools/android:" + tool],
    )
    for tool in [
        "aar_native_libs_zip_creator",
        "aar_embedded_jars_extractor",
        "aar_embedded_proguard_extractor",
        "aar_resources_extractor",
    ]
]

