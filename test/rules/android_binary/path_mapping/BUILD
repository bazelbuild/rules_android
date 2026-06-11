load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "script_test",
)
load("@rules_shell//shell:sh_library.bzl", "sh_library")

sh_library(
    name = "path_mapping_helper",
    testonly = True,
    srcs = ["path_mapping_helper.sh"],
    data = [
        "//:MODULE.bazel",
        "//rules:bzl",
    ],
    visibility = ["//visibility:private"],
    deps = [
        "//test/bashunit",
        "@rules_shell//shell/runfiles",
    ],
)

script_test(
    name = "path_mapping_integration_test",
    size = "enormous",
    timeout = "eternal",
    srcs = ["path_mapping_integration_test.sh"],
    additional_env_inherit = ["ANDROID_HOME"],
    bazel_binaries = bazel_binaries,
    bazel_version = bazel_binaries.versions.current,
    tags = ["manual"],
    deps = [
        ":path_mapping_helper",
        "//test/bashunit",
        "@rules_shell//shell/runfiles",
    ],
)
