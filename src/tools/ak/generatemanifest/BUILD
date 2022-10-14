load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Package for manifest generation module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_binary(
    name = "generatemanifest_bin",
    srcs = ["generatemanifest_bin.go"],
    deps = [
        ":generatemanifest",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "generatemanifest",
    srcs = ["generatemanifest.go"],
    importpath = "src/tools/ak/generatemanifest/generatemanifest",
    deps = [
        "//src/common/golang:flags",
        "//src/tools/ak:types",
    ],
)

go_test(
    name = "generatemanifest_test",
    size = "small",
    srcs = ["generatemanifest_test.go"],
    embed = [":generatemanifest"],
    deps = ["@com_github_google_go_cmp//cmp:go_default_library"],
)
