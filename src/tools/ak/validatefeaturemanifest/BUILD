load("@io_bazel_rules_go//go:def.bzl", "go_library")

licenses(["notice"])

go_library(
    name = "validatefeaturemanifest",
    srcs = [
        "validatefeaturemanifest.go",
    ],
    importpath = "src/tools/ak/validatefeaturemanifest/validatefeaturemanifest",
    visibility = ["//visibility:public"],
    deps = [
        "//src/common/golang:xml2",
        "//src/tools/ak:types",
    ],
)
