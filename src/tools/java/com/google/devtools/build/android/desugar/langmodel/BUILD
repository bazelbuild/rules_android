load("@com_google_protobuf//bazel:java_proto_library.bzl", "java_proto_library")
load("@com_google_protobuf//bazel:proto_library.bzl", "proto_library")
load("@rules_java//java:defs.bzl", "java_library")

package(
    default_visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/desugar:__subpackages__",
        "//src/tools/javatests/com/google/devtools/build/android/desugar:__subpackages__",
    ],
)

java_library(
    name = "langmodel",
    srcs = glob(["*.java"]),
    deps = [
        ":desugar_class_attr_java_proto",
        "//tools/android:autovalue",
        "@maven//:com_google_code_findbugs_jsr305",
        "@maven//:com_google_errorprone_error_prone_annotations",
        "@maven//:com_google_guava_guava",
        "@maven//:com_google_protobuf_protobuf_java",
        "@maven//:org_ow2_asm_asm",
        "@maven//:org_ow2_asm_asm_commons",
        "@maven//:org_ow2_asm_asm_tree",
    ],
)

proto_library(
    name = "desugar_class_attr_proto",
    srcs = [
        "desugar_method_attr.proto",
    ],
)

java_proto_library(
    name = "desugar_class_attr_java_proto",
    tags = ["manual"],
    deps = [":desugar_class_attr_proto"],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = ["//src/tools/java/com/google/devtools/build/android/desugar:__pkg__"],
)
