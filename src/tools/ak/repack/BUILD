load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Package for repack module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_binary(
    name = "repack_bin",
    srcs = ["repack_bin.go"],
    deps = [
        ":repack",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "repack",
    srcs = ["repack.go"],
    importpath = "src/tools/ak/repack/repack",
    deps = [
        "//src/common/golang:flags",
        "//src/tools/ak:types",
    ],
)

go_test(
    name = "repack_test",
    size = "small",
    srcs = ["repack_test.go"],
    embed = [":repack"],
)
