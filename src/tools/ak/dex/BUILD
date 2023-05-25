load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Package for dex compilation module
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_binary(
    name = "dex_bin",
    srcs = ["dex_bin.go"],
    deps = [
        ":dex",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "dex",
    srcs = ["dex.go"],
    importpath = "src/tools/ak/dex/dex",
    deps = [
        "//src/common/golang:flags",
        "//src/common/golang:shard",
        "//src/common/golang:ziputils",
        "//src/tools/ak:types",
    ],
)
