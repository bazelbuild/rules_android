load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

package(default_applicable_licenses = ["//:license"])

licenses(["notice"])

go_library(
    name = "resxml",
    srcs = ["xml_parser.go"],
    importpath = "src/tools/ak/res/resxml/resxml",
    visibility = ["//src/tools/ak/liteparse:__subpackages__"],
    deps = [
        "//src/tools/ak/res/respipe",
    ],
)

go_test(
    name = "resxml_test",
    size = "small",
    srcs = ["xml_parser_test.go"],
    embed = [":resxml"],
    deps = [
        "//src/tools/ak/res/respipe",
    ],
)
