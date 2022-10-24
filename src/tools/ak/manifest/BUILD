load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Package for manifest compilation module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_binary(
    name = "manifest_bin",
    srcs = ["manifest_bin.go"],
    deps = [
        ":manifest",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "manifest",
    srcs = [
        "manifest.go",
    ],
    importpath = "src/tools/ak/manifest/manifest",
    deps = [
        "//src/common/golang:flags",
        "//src/tools/ak:manifestutils",
        "//src/tools/ak:types",
    ],
)
