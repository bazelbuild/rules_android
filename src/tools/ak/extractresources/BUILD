# Description:
#   Package for the extractresources tool (formerly resource_extractor.py).

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

go_library(
    name = "extractresources",
    srcs = ["extractresources.go"],
    importpath = "src/tools/ak/extractresources/extractresources",
    deps = ["//src/tools/ak:types"],
)

go_binary(
    name = "extractresources_bin",
    srcs = ["extractresources_bin.go"],
    deps = [":extractresources"],
)

go_test(
    name = "extractresources_test",
    srcs = ["extractresources_test.go"],
    embed = [":extractresources"],
    deps = [
        "@com_github_google_go_cmp//cmp:go_default_library",
        "@com_github_google_go_cmp//cmp/cmpopts:go_default_library",
    ],
)
