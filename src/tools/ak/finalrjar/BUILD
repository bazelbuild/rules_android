load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Package for final R.jar module
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_library(
    name = "finalrjar",
    srcs = ["finalrjar.go"],
    importpath = "src/tools/ak/finalrjar/finalrjar",
    deps = [
        "//src/common/golang:ziputils",
        "//src/tools/ak:types",
    ],
)

go_binary(
    name = "finalrjar_bin",
    srcs = ["finalrjar_bin.go"],
    deps = [
        ":finalrjar",
        "//src/common/golang:flagfile",
    ],
)

go_test(
    name = "finalrjar_test",
    size = "small",
    srcs = ["finalrjar_test.go"],
    embed = [":finalrjar"],
    deps = ["@com_github_google_go_cmp//cmp:go_default_library"],
)
