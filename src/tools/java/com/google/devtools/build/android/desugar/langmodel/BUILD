load("@rules_proto//proto:defs.bzl", "proto_library")
load("@rules_java//java:defs.bzl", "java_library", "java_proto_library")

package(
    default_visibility = [
        "//src/test/java/com/google/devtools/build/android/desugar:__subpackages__",
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
        "//src/tools/java/com/google/devtools/build/android/desugar:__subpackages__",
    ],
)

java_library(
    name = "langmodel",
    srcs = glob(["*.java"]),
    deps = [
        ":desugar_class_attr_java_proto",
        "//tools/android:autovalue",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_errorprone_error_prone_annotations",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_protobuf_protobuf_java",
        "@rules_android_maven//:org_ow2_asm_asm",
        "@rules_android_maven//:org_ow2_asm_asm_commons",
        "@rules_android_maven//:org_ow2_asm_asm_tree",
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
