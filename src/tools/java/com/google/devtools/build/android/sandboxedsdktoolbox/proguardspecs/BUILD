# Command to generate proguard specs for an SDK modules config.

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
    name = "proguardspecs",
    srcs = ["GenerateSdkProguardSpecsCommand.java"],
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/info",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
