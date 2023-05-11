load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Package for shellapk module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_binary(
    name = "shellapk_bin",
    srcs = ["shellapk_bin.go"],
    deps = [
        ":shellapk",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "shellapk",
    srcs = ["shellapk.go"],
    importpath = "src/tools/ak/shellapk/shellapk",
    deps = [
        "//src/common/golang:fileutils",
        "//src/common/golang:flags",
        "//src/common/golang:ziputils",
        "//src/tools/ak:types",
    ],
)

go_test(
    name = "shellapk_test",
    size = "small",
    srcs = ["shellapk_test.go"],
    data = [
        "//src/tools/ak/shellapk/testdata:android_manifest",
        "//src/tools/ak/shellapk/testdata:app_name",
        "//src/tools/ak/shellapk/testdata:dexes",
        "//src/tools/ak/shellapk/testdata:manifest_package_name",
        "//src/tools/ak/shellapk/testdata:native_lib",
        "//src/tools/ak/shellapk/testdata:res",
    ],
    embed = [":shellapk"],
    tags = ["manual"],
)
