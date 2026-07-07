# Utilities for extracting information from SDK archives and Bundle metadata.
load("@rules_java//java:defs.bzl", "java_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "info",
    srcs = glob(["*.java"]),
    deps = [
        "@com_google_protobuf//:protobuf_java",
        "@com_google_protobuf//:protobuf_java_util",
        "@rules_android_maven//:com_android_tools_build_bundletool",
    ],
)
