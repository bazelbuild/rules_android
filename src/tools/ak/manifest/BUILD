load("@io_bazel_rules_go//:def.bzl", "go_binary", "go_library", "go_test", "go_proto_library")
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
    deps = [
        "//src/common/golang:flags",
        "//src/tools/ak:manifestutils",
        "//src/tools/ak:types",
    ],
)
