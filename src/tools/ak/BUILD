# Description:
#   Top level package for ak, a "busybox" for various minor build-related tools.

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]) + [
        "//src/tools/ak/bucketize:all_files",
        "//src/tools/ak/compile:all_files",
        "//src/tools/ak/dex:all_files",
        "//src/tools/ak/extractaar:all_files",
        "//src/tools/ak/extractresources:all_files",
        "//src/tools/ak/finalrjar:all_files",
        "//src/tools/ak/generatemanifest:all_files",
        "//src/tools/ak/link:all_files",
        "//src/tools/ak/liteparse:all_files",
        "//src/tools/ak/manifest:all_files",
        "//src/tools/ak/minsdkfloor:all_files",
        "//src/tools/ak/nativelib:all_files",
        "//src/tools/ak/patch:all_files",
        "//src/tools/ak/proto:all_files",
        "//src/tools/ak/repack:all_files",
        "//src/tools/ak/res:all_files",
        "//src/tools/ak/rjar:all_files",
    ],
    visibility = ["//:__pkg__"]
)

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
        "//src/tools/ak/extractresources",
        "//src/tools/ak/finalrjar",
        "//src/tools/ak/generatemanifest",
        "//src/tools/ak/link",
        "//src/tools/ak/liteparse",
        "//src/tools/ak/manifest",
        "//src/tools/ak/minsdkfloor",
        "//src/tools/ak/nativelib",
        "//src/tools/ak/patch",
        "//src/tools/ak/repack",
        "//src/tools/ak/rjar",
    ],
)
