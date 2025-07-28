load("@com_google_protobuf//bazel:java_proto_library.bzl", "java_proto_library")
load("@com_google_protobuf//bazel:proto_library.bzl", "proto_library")

package(default_visibility = ["//visibility:public"])

# Largely copied from https://github.com/bazelbuild/bazel/blob/master/src/main/protobuf/BUILD

FILES = [
    "deps",
    "desugar_deps",
    "java_compilation",
]

[proto_library(
    name = s + "_proto",
    srcs = [s + ".proto"],
) for s in FILES]

[java_proto_library(
    name = s + "_java_proto",
    deps = [":" + s + "_proto"],
) for s in FILES]
