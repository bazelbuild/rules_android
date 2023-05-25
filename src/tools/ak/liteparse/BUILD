load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Package for parse module
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_library(
    name = "liteparse",
    srcs = [
        "liteparse.go",
        "non_values_parse.go",
        "values_parse.go",
    ],
    importpath = "src/tools/ak/liteparse/liteparse",
    deps = [
        "//src/common/golang:flags",
        "//src/common/golang:walk",
        "//src/tools/ak:types",
        "//src/tools/ak/res",
        "//src/tools/ak/res/proto:res_data_go_proto",
        "//src/tools/ak/res/proto:res_meta_go_proto",
        "//src/tools/ak/res/respipe",
        "//src/tools/ak/res/resxml",
        "@org_golang_google_protobuf//proto",
    ],
)

go_test(
    name = "liteparse_test",
    size = "small",
    srcs = [
        "liteparse_test.go",
        "non_values_parse_test.go",
        "values_parse_test.go",
    ],
    data = glob(["testdata/**"]),
    embed = [":liteparse"],
    deps = [
        "//src/common/golang:runfilelocation",
        "//src/tools/ak/res",
        "//src/tools/ak/res/proto:res_data_go_proto",
        "//src/tools/ak/res/respipe",
        "//src/tools/ak/res/resxml",
        "@com_github_google_go_cmp//cmp:go_default_library",
    ],
)

go_binary(
    name = "liteparse_bin",
    srcs = ["liteparse_bin.go"],
    deps = [
        ":liteparse",
        "//src/common/golang:flagfile",
    ],
)
