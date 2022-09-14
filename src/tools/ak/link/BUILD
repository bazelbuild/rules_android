load("@io_bazel_rules_go//:def.bzl", "go_binary", "go_library", "go_test", "go_proto_library")
# Description:
#   Package for link module
package(default_visibility = ["//visibility:public"])

licenses(["notice"])

go_binary(
    name = "link_bin",
    srcs = ["link_bin.go"],
    deps = [
        ":link",
        "//src/common/golang:flagfile",
    ],
)

go_library(
    name = "link",
    srcs = [
        "link.go",
    ],
    deps = [
        "//src/common/golang:flags",
        "//src/common/golang:walk",
        "//src/common/golang:ziputils",
        "//src/tools/ak:types",
    ],
)
