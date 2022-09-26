load("@io_bazel_rules_go//:def.bzl", "go_binary", "go_library", "go_test")
# Description:
#   Package for compile module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_binary(
    name = "compile_bin",
    srcs = ["compile_bin.go"],
    deps = [
        ":compile",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "compile",
    srcs = [
        "compile.go",
    ],
    deps = [
        "//src/common/golang:ziputils",
        "//src/tools/ak:types",
    ],
)

go_test(
    name = "compile_test",
    size = "small",
    srcs = [
        "compile_test.go",
    ],
    library = ":compile",
)
