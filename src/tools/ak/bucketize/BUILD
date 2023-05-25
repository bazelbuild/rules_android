load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Package for bucketize module
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_binary(
    name = "bucketize_bin",
    srcs = ["bucketize_bin.go"],
    deps = [
        ":bucketize",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "bucketize",
    srcs = [
        "bucketize.go",
        "partitioner.go",
        "pipe.go",
    ],
    importpath = "src/tools/ak/bucketize/bucketize",
    deps = [
        "//src/common/golang:flags",
        "//src/common/golang:shard",
        "//src/common/golang:walk",
        "//src/common/golang:xml2",
        "//src/tools/ak:akhelper",
        "//src/tools/ak:types",
        "//src/tools/ak/res",
    ],
)

go_test(
    name = "bucketize_test",
    size = "small",
    srcs = [
        "bucketize_test.go",
        "partitioner_test.go",
    ],
    embed = [":bucketize"],
    deps = [
        "//src/common/golang:shard",
        "//src/common/golang:walk",
        "//src/tools/ak/res",
    ],
)

go_test(
    name = "pipe_test",
    size = "small",
    srcs = ["pipe_test.go"],
    embed = [":bucketize"],
)
