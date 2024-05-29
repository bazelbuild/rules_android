# Rule-specific implementations for the mobile-install aspect
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    deps = [
        "//mobile_install:launcher_direct",
        "//mobile_install:providers",
        "//mobile_install:resources",
        "//mobile_install:transform",
        "//mobile_install:utils",
        "//rules:visibility_bzl",
        "@rules_java//java/common",
    ],
)

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)
