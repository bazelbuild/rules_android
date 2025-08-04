# Description:
#   Dependency tracking helper library for desugar that we package separately
#   for the benefit of desugar users who want to compile the tool from source.

load("@rules_java//java:defs.bzl", "java_library")

package(
    default_visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/desugar:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/r8:__pkg__",
        "//src/tools/javatests/com/google/devtools/build/android/desugar:__subpackages__",
    ],
)

java_library(
    name = "dependencies",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/r8:deps_collector_api",
        "//src/main/protobuf:desugar_deps_java_proto",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
)
