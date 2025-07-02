# Description:
#   Tool for desugaring Java constructs not supported by Android tools or devices.

load("@rules_java//java:defs.bzl", "java_library")

java_library(
    name = "desugar",
    tags = ["manual"],
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/desugar/testing/junit:__pkg__",
        "//src/tools/javatests/com/google/devtools/build/android/desugar:__pkg__",
    ],
    exports = [
        "//src/tools/java/com/google/devtools/build/android/desugar/dependencies",
        "//src/tools/java/com/google/devtools/build/android/desugar/io",
        "//src/tools/java/com/google/devtools/build/android/desugar/langmodel",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]) + [
        "//src/tools/java/com/google/devtools/build/android/desugar/dependencies:srcs",
        "//src/tools/java/com/google/devtools/build/android/desugar/io:srcs",
        "//src/tools/java/com/google/devtools/build/android/desugar/langmodel:srcs",
        "//src/tools/java/com/google/devtools/build/android/desugar/scan:srcs",
    ],
    visibility = ["//src/tools/java/com/google/devtools/build/android:__pkg__"],
)
