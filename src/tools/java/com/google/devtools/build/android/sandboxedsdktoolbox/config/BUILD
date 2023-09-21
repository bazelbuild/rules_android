# Utilities for SDK module config proto message.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "config",
    srcs = glob(["*.java"]),
    deps = [
        "@rules_android_maven//:com_android_tools_build_bundletool",
        "@rules_android_maven//:com_google_protobuf_protobuf_java_util",
    ],
)
