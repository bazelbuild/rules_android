# Description:
#   Package for R.jar module

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//src/tools/ak:__pkg__"],
)

go_library(
    name = "rjar",
    srcs = ["rjar.go"],
    importpath = "src/tools/ak/rjar/rjar",
    deps = [
        "//src/common/golang:ziputils",
        "//src/tools/ak:types",
    ],
)

go_binary(
    name = "rjar_bin",
    srcs = ["rjar_bin.go"],
    deps = [
        ":rjar",
        "//src/common/golang:flagfile",
    ],
)

go_test(
    name = "rjar_test",
    size = "small",
    srcs = ["rjar_test.go"],
    args = ["--java_path=$(location @local_jdk//:bin/java:java)"],
    data = [
        "//src/tools/ak/rjar/testdata:R",
        "//src/tools/ak/rjar/testdata:pkgs",
        "@local_jdk//:bin/java",
        "@remote_java_tools_for_rules_android//:java_tools/JavaBuilder_deploy.jar",
    ],
    embed = [":rjar"],
    tags = [
        "manual",
        "not_run:arm",
        "nozapfhahn",
    ],
)
