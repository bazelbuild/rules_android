load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

go_proto_library(
    name = "android_deploy_info_go_proto",
    importpath = "src/tools/deploy_info/proto/android_deploy_info_go_proto",
    protos = [
        "@bazel_tools//src/main/protobuf:android_deploy_info_proto",
    ],
    visibility = [
        "//src/tools/deploy_info:__pkg__",
    ],
)
