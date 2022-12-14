load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Package for extractaar module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_library(
    name = "extractaar",
    srcs = [
        "buildozer.go",
        "extractaar.go",
        "validator.go",
    ],
    importpath = "src/tools/ak/extractaar/extractaar",
    deps = [
        "//src/tools/ak:types",
    ],
)

go_binary(
    name = "extractaar_bin",
    srcs = ["extractaar_bin.go"],
    deps = [
        ":extractaar",
        "//src/common/golang:flagfile",
    ],
)

go_test(
    name = "extractaar_test",
    size = "small",
    srcs = [
        "extractaar_test.go",
        "validator_test.go",
    ],
    embed = [":extractaar"],
    deps = [
        "@com_github_google_go_cmp//cmp:go_default_library",
        "@com_github_google_go_cmp//cmp/cmpopts:go_default_library",
    ],
)
