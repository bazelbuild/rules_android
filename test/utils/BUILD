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
        "//rules:providers_bzl",
        "//rules:visibility_bzl",
        "@rules_java//java:core_rules",
        "@bazel_skylib//lib:unittest",
    ],
)
