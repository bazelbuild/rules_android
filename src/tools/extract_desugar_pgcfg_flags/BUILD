load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

# Utility and test for extracting pgcfg flags from the desugar_jdk_libs config JSON file.
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

licenses(["notice"])

go_binary(
    name = "extract_desugar_pgcfg_flags",
    srcs = ["extract_desugar_pgcfg_flags.go"],
)

sh_test(
    name = "extract_desugar_pgcfg_flags_test",
    srcs = ["extract_desugar_pgcfg_flags_test.sh"],
    args = ["--binary_under_test $(location :extract_desugar_pgcfg_flags)"],
    data = [":extract_desugar_pgcfg_flags"],
)
