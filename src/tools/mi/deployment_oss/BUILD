load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src/tools/mi/deployment_oss:__pkg__"],
)

go_binary(
    name = "deploy_binary",
    srcs = ["deploy_binary.go"],
    visibility = ["//visibility:public"],
    deps = [
        "//src/common/golang:flagfile",
        "//src/common/golang:flags",
        "//src/common/golang:pprint",
        "//src/tools/mi/deployment_oss:deployment",
        "@com_github_golang_glog//:glog",
    ],
)

go_library(
    name = "deployment",
    importpath = "src/tools/mi/deployment_oss/deployment",

    srcs = [
        "deploy.go",
    ],
    visibility = ["//src/tools/mi:__subpackages__"],
    deps = ["//src/common/golang:pprint"],
)

build_test(
    name = "deploy_binary_build_test",
    targets = [":deploy_binary"]
)