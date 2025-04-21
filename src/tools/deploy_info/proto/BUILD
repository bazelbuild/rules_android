load("@com_google_protobuf//bazel:java_proto_library.bzl", "java_proto_library")
load("@com_google_protobuf//bazel:proto_library.bzl", "proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//src/tools/deploy_info:__pkg__"],
)

proto_library(
    name = "android_deploy_info_proto",
    srcs = ["android_deploy_info.proto"],
    visibility = ["//visibility:public"],
)

java_proto_library(
    name = "android_deploy_info_java_proto",
    visibility = ["//visibility:public"],
    deps = [":android_deploy_info_proto"],
)

go_proto_library(
    name = "android_deploy_info_go_proto",
    importpath = "src/tools/deploy_info/proto/android_deploy_info_go_proto",
    protos = [":android_deploy_info_proto"],
    visibility = ["//visibility:public"],
)
