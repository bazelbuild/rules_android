# Command to extract API descriptors from a sandboxed SDK.

load("@rules_java//java:defs.bzl", "java_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = ["//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox:__pkg__"],
)

java_library(
    name = "apidescriptors",
    srcs = glob(["*.java"]),
    deps = [
        "@rules_android_maven//:androidx_privacysandbox_tools_tools_apipackager",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
