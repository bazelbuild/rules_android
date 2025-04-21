load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//src/tools/jdeps:__pkg__"],
)

go_proto_library(
    name = "deps_go_proto",
    importpath = "src/tools/jdeps/proto/deps_go_proto",
    protos = [
        "@bazel_tools//src/main/protobuf:deps_proto",
    ],
    visibility = [
        "//src/tools/jdeps:__pkg__",
    ],
)
