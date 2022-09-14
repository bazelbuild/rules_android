load("@io_bazel_rules_go//:def.bzl", "go_binary", "go_library", "go_test", "go_proto_library")
# Description:
#   Package for mindex module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_binary(
    name = "mindex_bin",
    srcs = ["mindex_bin.go"],
    deps = [
        ":mindex",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "mindex",
    srcs = ["mindex.go"],
    deps = ["//src/tools/ak:types"],
)
