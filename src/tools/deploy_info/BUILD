load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_binary(
    name = "deploy_info",
    srcs = ["deploy_info.go"],
    deps = [
        "//src/common/golang:flagfile",
        "//src/common/golang:flags",
        "//src/tools/deploy_info/proto:android_deploy_info_go_proto",
        "@org_golang_google_protobuf//proto",
    ],
)
