load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

package(default_applicable_licenses = ["//:license"])

licenses(["notice"])

go_library(
    name = "respipe",
    srcs = [
        "errors.go",
        "path_emitter.go",
        "res_io.go",
        "streams.go",
    ],
    importpath = "src/tools/ak/res/respipe/respipe",
    visibility = [
        "//src/tools/ak:__subpackages__",
        "//src/tools/resource_extractor:__subpackages__",
        "//tools/android/incremental:__subpackages__",
    ],
    deps = [
        "//src/tools/ak/res",
        "//src/tools/ak/res/proto:res_data_go_proto",
        "@org_golang_google_protobuf//proto",
    ],
)

go_test(
    name = "respipe_test",
    size = "small",
    srcs = [
        "errors_test.go",
        "path_emitter_test.go",
        "res_io_test.go",
        "streams_test.go",
    ],
    embed = [":respipe"],
    deps = [
        "//src/tools/ak/res",
        "//src/tools/ak/res/proto:res_data_go_proto",
        "@org_golang_google_protobuf//proto",
    ],
)
