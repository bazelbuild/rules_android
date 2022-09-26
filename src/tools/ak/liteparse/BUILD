load("@io_bazel_rules_go//:def.bzl", "go_binary", "go_library", "go_test")
# Description:
#   Package for parse module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_library(
    name = "liteparse",
    srcs = [
        "liteparse.go",
        "non_values_parse.go",
        "values_parse.go",
    ],
    deps = [
        "//src/common/golang:flags",
        "//src/common/golang:walk",
        "//src/tools/ak:types",
        "//src/tools/ak/res",
        "//src/tools/ak/res/proto:res_data_go_proto",
        "//src/tools/ak/res/proto:res_meta_go_proto",
        "//src/tools/ak/res/respipe",
        "//src/tools/ak/res/resxml",
        "@com_github_golang_protobuf//proto",
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
    library = ":liteparse",
    deps = [
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
