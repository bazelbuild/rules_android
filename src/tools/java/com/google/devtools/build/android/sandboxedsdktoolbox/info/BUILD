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
        "@maven//:com_android_tools_build_bundletool",
        "@maven//:com_google_protobuf_protobuf_java",
        "@maven//:com_google_protobuf_protobuf_java_util",
    ],
)
