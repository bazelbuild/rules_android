load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Package for nativelib module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_library(
    name = "nativelib",
    srcs = ["nativelib.go"],
    importpath = "src/tools/ak/nativelib/nativelib",
    deps = [
        "//src/common/golang:fileutils",
        "//src/common/golang:flags",
        "//src/common/golang:ziputils",
        "//src/tools/ak:types",
    ],
)

go_binary(
    name = "nativelib_bin",
    srcs = ["nativelib_bin.go"],
    deps = [
        ":nativelib",
        "//src/common/golang:flagfile",
    ],
)

go_test(
    name = "nativelib_test",
    size = "small",
    srcs = ["nativelib_test.go"],
    data = [
        "//src/tools/ak/nativelib/testdata:dummy_so",
    ],
    embed = [":nativelib"],
    deps = ["//src/common/golang:runfilelocation"],
)
