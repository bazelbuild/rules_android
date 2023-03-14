load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Common libraries and utilities.
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_library(
    name = "xml2",
    srcs = ["marshal.go"],
    importpath = "src/common/golang/xml2",
)

go_test(
    name = "xml2_test",
    size = "small",
    srcs = [
        "marshal_test.go",
    ],
    embed = [":xml2"],
)

go_library(
    name = "shard",
    srcs = ["shard.go"],
    importpath = "src/common/golang/shard",
)

go_test(
    name = "shard_test",
    size = "small",
    srcs = [
        "shard_test.go",
        "zipshard_test.go",
    ],
    embed = [":shard"],
)

go_library(
    name = "walk",
    srcs = ["walk.go"],
    importpath = "src/common/golang/walk",
)

go_library(
    name = "ziputils",
    srcs = ["ziputils.go"],
    importpath = "src/common/golang/ziputils",
    deps = ["@org_golang_x_sync//errgroup"],
)

go_library(
    name = "fileutils",
    srcs = ["fileutils.go"],
    importpath = "src/common/golang/fileutils",
)

go_library(
    name = "flags",
    srcs = ["flags.go"],
    importpath = "src/common/golang/flags",
)

go_test(
    name = "flagfile_test",
    size = "small",
    srcs = ["flagfile_test.go"],
    embed = [":flagfile"],
)

go_library(
    name = "ini",
    srcs = ["ini.go"],
    importpath = "src/common/golang/ini",
)

go_test(
    name = "ini_test",
    size = "small",
    srcs = ["ini_test.go"],
    embed = [":ini"],
)

go_library(
    name = "pprint",
    srcs = ["pprint.go"],
    importpath = "src/common/golang/pprint",
)

go_library(
    name = "flagfile",
    srcs = ["flagfile.go"],
    importpath = "src/common/golang/flagfile",
)

genrule(
    name = "a_txt",
    outs = ["a.txt"],
    cmd = "echo hello world > $@",
)

go_library(
    name = "runfilelocation",
    srcs = ["runfilelocation.go"],
    importpath = "src/common/golang/runfilelocation",
    deps = ["@io_bazel_rules_go//go/runfiles"],
)

go_test(
    name = "runfilelocation_test",
    srcs = ["runfilelocation_test.go"],
    data = [":a_txt"],
    embed = [":runfilelocation"],
)
