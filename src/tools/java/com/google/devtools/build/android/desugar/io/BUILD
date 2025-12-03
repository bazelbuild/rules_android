# Description:
#   Tool for desugaring Java constructs not supported by Android tools or devices.

load("@rules_java//java:defs.bzl", "java_library")

java_library(
    name = "io",
    srcs = glob(["*.java"]),
    tags = ["manual"],
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/desugar:__subpackages__",
        "//src/tools/javatests/com/google/devtools/build/android/desugar:__subpackages__",
    ],
    deps = [
        "//src/tools/java/com/google/devtools/build/android/desugar/langmodel",
        "//src/tools/java/com/google/devtools/build/android/ziputils:ziputils_lib",
        "//tools/android:autovalue",
        "@maven//:com_google_auto_value_auto_value",
        "@maven//:com_google_code_findbugs_jsr305",
        "@maven//:com_google_errorprone_error_prone_annotations",
        "@maven//:com_google_flogger_flogger",
        "@maven//:com_google_guava_guava",
        "@maven//:jakarta_inject_jakarta_inject_api",
        "@maven//:org_ow2_asm_asm",
        "@maven//:org_ow2_asm_asm_commons",
        "@maven//:org_ow2_asm_asm_tree",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = ["//src/tools/java/com/google/devtools/build/android/desugar:__pkg__"],
)
