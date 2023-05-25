load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Top level package for ak, a "busybox" for various minor build-related tools.
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_binary(
    name = "ak",
    srcs = [
        "ak.go",
    ],
    deps = [
        ":akcommands",
        ":types",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "types",
    srcs = ["types.go"],
    importpath = "src/tools/ak/types",
)

go_library(
    name = "akhelper",
    srcs = ["akhelper.go"],
    importpath = "src/tools/ak/akhelper",
)

go_library(
    name = "manifestutils",
    srcs = ["manifestutils.go"],
    importpath = "src/tools/ak/manifestutils",
    deps = [
        "//src/common/golang:xml2",
    ],
)

go_library(
    name = "akcommands",
    srcs = ["akcommands.go"],
    importpath = "src/tools/ak/akcommands",
    deps = [
        ":types",
        "//src/tools/ak/bucketize",
        "//src/tools/ak/compile",
        "//src/tools/ak/dex",
        "//src/tools/ak/extractaar",
        "//src/tools/ak/finalrjar",
        "//src/tools/ak/generatemanifest",
        "//src/tools/ak/link",
        "//src/tools/ak/liteparse",
        "//src/tools/ak/manifest",
        "//src/tools/ak/mindex",
        "//src/tools/ak/nativelib",
        "//src/tools/ak/patch",
        "//src/tools/ak/repack",
        "//src/tools/ak/rjar",
        "//src/tools/ak/shellapk",
    ],
)
