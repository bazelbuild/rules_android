load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Protocol buffer definitions used by AK
package(default_visibility = ["//src/tools/ak/package:__subpackages__"])

licenses(["notice"])

proto_library(
    name = "sync_proto",
    srcs = ["sync.proto"],
)
