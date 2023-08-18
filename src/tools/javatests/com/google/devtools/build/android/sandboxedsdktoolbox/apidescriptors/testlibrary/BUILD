# Library to test SDK API descritptor extraction.

load("//rules:rules.bzl", "android_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

android_library(
    name = "testlibrary",
    srcs = glob(["**/*.java"]),
    deps = [
        "@rules_android_maven//:androidx_privacysandbox_tools_tools",
    ],
)
