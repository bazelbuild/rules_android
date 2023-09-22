# Utilities for extracting information from SDK archives and Bundle metadata.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "info",
    srcs = glob(["*.java"]),
    deps = [
        "@rules_android_maven//:com_android_tools_build_bundletool",
        "@rules_android_maven//:com_google_protobuf_protobuf_java",
        "@rules_android_maven//:com_google_protobuf_protobuf_java_util",
    ],
)
