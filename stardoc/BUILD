load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@stardoc//stardoc:stardoc.bzl", "stardoc")

bzl_library(
    name = "doc_rules",
    srcs = ["doc_rules.bzl"],
    deps = ["//rules:bzl"],
)

# Run with `--workspace_status_command='echo STABLE_GIT_COMMIT $(git rev-parse HEAD)'`
# to get the git commit stamping in the header.
stardoc(
    name = "stardoc",
    out = "stardoc.md",
    input = "doc_rules.bzl",
    header_template = "header_template.vm",
    table_of_contents_template = "table_of_contents_template.vm",
    footer_template = "footer_template.vm",
    stamp = True,
    deps = [":doc_rules"],
)

build_test(
    name = "stardoc_build_test",
    targets = [":stardoc"],
)
