load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description
#   Android resources proto
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

proto_library(
    name = "res_meta_proto",
    srcs = ["res_meta.proto"],
)

go_proto_library(
    name = "res_meta_go_proto",
    importpath = "src/tools/ak/res/proto/res_meta_go_proto",
    protos = [":res_meta_proto"],
)

proto_library(
    name = "res_data_proto",
    srcs = ["res_data.proto"],
    deps = [":res_meta_proto"],
)

go_proto_library(
    name = "res_data_go_proto",
    importpath = "src/tools/ak/res/proto/res_data_go_proto",
    protos = [":res_data_proto"],
    deps = [":res_meta_go_proto"],
)
