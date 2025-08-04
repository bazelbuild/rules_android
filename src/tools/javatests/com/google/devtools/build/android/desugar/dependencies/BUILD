# Description:
#   Tests for the dependency tracking helper library for desugar.

load("@rules_java//java:defs.bzl", "java_test")

package(
    default_testonly = 1,
)

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "srcs",
    testonly = 0,
    srcs = glob(["*"]),
    visibility = ["//src/tools/javatests/com/google/devtools/build/android/desugar:__pkg__"],
)

java_test(
    name = "MetadataCollectorTest",
    size = "small",
    srcs = ["MetadataCollectorTest.java"],
    deps = [
        "//src/tools/java/com/google/devtools/build/android/desugar/dependencies",
        "//src/main/protobuf:desugar_deps_java_proto",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)
