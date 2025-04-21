# Command for generating an SDK dependencies Android manifest.
load("@rules_java//java:defs.bzl", "java_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src:__subpackages__"],
)

licenses(["notice"])

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = ["//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox:__pkg__"],
)

java_library(
    name = "sdkdependenciesmanifest",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/info",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/mixin",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
