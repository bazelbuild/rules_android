# Description:
#   Package for link module

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_binary(
    name = "link_bin",
    srcs = ["link_bin.go"],
    deps = [
        ":link",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "link",
    srcs = [
        "link.go",
    ],
    importpath = "src/tools/ak/link/link",
    deps = [
        "//src/common/golang:flags",
        "//src/common/golang:walk",
        "//src/common/golang:ziputils",
        "//src/tools/ak:types",
    ],
)
