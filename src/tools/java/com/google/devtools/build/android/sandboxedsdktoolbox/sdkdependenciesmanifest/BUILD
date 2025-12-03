# Command for generating an SDK dependencies Android manifest.
load("@rules_java//java:defs.bzl", "java_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "sdkdependenciesmanifest",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/info",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/mixin",
        "@maven//:com_google_guava_guava",
        "@maven//:info_picocli_picocli",
    ],
)
