load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
# Creates test data for testing the nativelib action.

package(default_visibility = ["//src/tools/ak/nativelib:__subpackages__"])

licenses(["notice"])

genrule(
    name = "dummy_so",
    outs = ["dummy.so"],
    cmd = "touch $@",
)
