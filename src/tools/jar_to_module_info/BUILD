load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

go_binary(
    name = "jar_to_module_info",
    embed = [":jar_to_module_info_lib"],
    visibility = ["//visibility:public"],
)

go_library(
    name = "jar_to_module_info_lib",
    importpath = "src/tools/jar_to_module_info/jar_to_module_info_lib",

    srcs = ["jar_to_module_info.go"],
    visibility = ["//visibility:private"],
    deps = ["@org_bitbucket_creachadair_stringset//:stringset"],
)
