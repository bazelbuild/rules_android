load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

# Description:
#   Package for mindex module
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

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
    importpath = "src/tools/ak/mindex/mindex",
    deps = ["//src/tools/ak:types"],
)
