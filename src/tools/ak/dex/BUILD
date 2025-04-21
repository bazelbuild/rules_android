# Package for dex compilation module

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//src/tools/ak:__pkg__"],
)

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
