load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//:__pkg__"],
)

go_binary(
    name = "split_core_jar",
    embed = [":split_core_jar_lib"],
    visibility = ["//visibility:public"],
)

go_library(
    name = "split_core_jar_lib",
    importpath = "src/tools/split_core_jar/split_core_jar_lib",

    srcs = ["split_core_jar.go"],
    visibility = ["//visibility:private"],
    deps = ["@org_bitbucket_creachadair_stringset//:stringset"],
)
