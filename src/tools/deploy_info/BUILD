load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

package(default_applicable_licenses = ["//:license"])

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]) + [
        "//src/tools/deploy_info/proto:all_files",
    ],
    visibility = ["//:__pkg__"],
)

DEPLOY_INFO_VISIBILITY_GOOGLE3 = [
    "//mobile_install:__subpackages__",
    "//test/mobile_install:__subpackages__",
    "//toolchains/android:__subpackages__",
    "//tools/android/mi/testing:__pkg__",
]

# buildifier: disable=unused-variable
DEPLOY_INFO_VISIBILITY_OSS = [
    "//visibility:public",
]

go_binary(
    name = "deploy_info",
    srcs = ["deploy_info.go"],
    visibility = DEPLOY_INFO_VISIBILITY_OSS,
    deps = [
        "//src/common/golang:flagfile",
        "//src/common/golang:flags",
        "//src/tools/deploy_info/proto:android_deploy_info_go_proto",
        "@org_golang_google_protobuf//proto",
    ],
)
