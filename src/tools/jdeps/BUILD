load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

# Description:
#   Package for tool to filter a jdeps proto
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_binary(
    name = "jdeps",
    srcs = ["jdeps.go"],
    deps = [
        "//src/tools/jdeps/proto:deps_go_proto",
        "@org_golang_google_protobuf//proto",
    ],
)

go_binary(
    name = "print_jdeps",
    srcs = ["print_jdeps.go"],
    deps = [
        "//src/tools/jdeps/proto:deps_go_proto",
        "@org_golang_google_protobuf//proto",
    ],
)

sh_test(
    name = "jdeps_test",
    srcs = ["jdeps_test.sh"],
    data = [
        "testdata/test_data.jdeps",
        ":jdeps",
        ":print_jdeps",
    ],
)
