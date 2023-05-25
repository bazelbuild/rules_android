load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Package for patch module
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_binary(
    name = "patch_bin",
    srcs = ["patch_bin.go"],
    deps = [
        ":patch",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "patch",
    srcs = ["patch.go"],
    importpath = "src/tools/ak/patch/patch",
    deps = [
        "//src/common/golang:flags",
        "//src/tools/ak:manifestutils",
        "//src/tools/ak:types",
    ],
)

go_test(
    name = "patch_test",
    size = "small",
    srcs = ["patch_test.go"],
    embed = [":patch"],
    deps = [
        "//src/common/golang:xml2",
        "//src/tools/ak:manifestutils",
    ],
)
