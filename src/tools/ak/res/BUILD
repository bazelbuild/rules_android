# Description:
#   Package for res module

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_library(
    name = "res",
    srcs = [
        "naming.go",
        "path.go",
        "struct.go",
        "xml.go",
    ],
    importpath = "src/tools/ak/res/res",
    visibility = [
        "//src/tools/ak:__subpackages__",
        "//src/tools/resource_extractor:__subpackages__",
    ],
    deps = [
        "//src/tools/ak/res/proto:res_data_go_proto",
        "//src/tools/ak/res/proto:res_meta_go_proto",
        "@org_golang_google_protobuf//proto",
    ],
)

go_test(
    name = "res_test",
    size = "small",
    srcs = [
        "naming_test.go",
        "path_test.go",
        "struct_test.go",
    ],
    embed = [":res"],
)
