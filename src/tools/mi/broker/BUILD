# Description:
#   Device broker packages.

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

package(default_applicable_licenses = ["//:license"])

licenses(["notice"])

go_library(
    name = "adb",
    srcs = ["adb.go"],
    importpath = "src/tools/mi/broker/adb",
    visibility = ["//visibility:public"],
    deps = ["//src/common/golang:pprint"],
)

go_test(
    name = "adb_test",
    size = "small",
    srcs = ["adb_test.go"],
    embed = [":adb"],
)

go_library(
    name = "device",
    srcs = ["device.go"],
    importpath = "src/tools/mi/broker/device",
    visibility = ["//visibility:public"],
    deps = [
        ":adb",
        "//src/common/golang:pprint",
    ],
)

go_test(
    name = "device_test",
    size = "small",
    srcs = ["device_test.go"],
    embed = [":device"],
    deps = ["@com_github_google_go_cmp//cmp:go_default_library"],
)
