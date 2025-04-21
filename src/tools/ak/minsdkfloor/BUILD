# Description:
#   Package for tool to enforce min SDK floor on AndroidManifests

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src/tools/ak:__pkg__"],
)

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//src/tools/ak:__pkg__"],
)

go_library(
    name = "minsdkfloor",
    srcs = ["minsdkfloor.go"],
    importpath = "src/tools/ak/minsdkfloor/minsdkfloor",
    deps = [
        "//src/common/golang:xml2",
        "//src/tools/ak:types",
    ],
)

go_binary(
    name = "minsdkfloor_bin",
    srcs = ["minsdkfloor_bin.go"],
    deps = [
        ":minsdkfloor",
        "//src/common/golang:flagfile",
    ],
)

go_test(
    name = "minsdkfloor_test",
    srcs = ["minsdkfloor_test.go"],
    embed = [":minsdkfloor"],
)
