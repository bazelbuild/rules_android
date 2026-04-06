load("@bazel_binaries//:defs.bzl", "bazel_binaries")
load("@bazel_skylib//rules:build_test.bzl", "build_test")
load(
    "@rules_bazel_integration_test//bazel_integration_test:defs.bzl",
    "script_test",
)
load("@rules_python//python:py_test.bzl", "py_test")
load("@rules_shell//shell:sh_library.bzl", "sh_library")
load(":test.bzl", "r8_neverlink_deps_test")

py_test(
    name = "r8_integration_test",
    srcs = ["r8_integration_test.py"],
    args = ["$(location @androidsdk//:dexdump)"],
    data = [
        "//test/rules/android_binary/r8_integration/java/com/basicapp:basic_app_R8_no_shrink",
        "//test/rules/android_binary/r8_integration/java/com/basicapp:basic_app_R8_shrink",
        "//test/rules/android_binary/r8_integration/java/com/basicapp:basic_app_no_R8",
        "//test/rules/android_binary/r8_integration/java/com/basicapp:basic_app_select_R8_generate_pg_map",
        "@androidsdk//:dexdump",
    ],
)

r8_neverlink_deps_test(
    name = "r8_neverlink_deps_test",
    target_under_test = "//test/rules/android_binary/r8_integration/java/com/neverlink:android_binary_with_neverlink_deps",
)

build_test(
    name = "android_binary_with_neverlink_deps_build_test",
    targets = ["//test/rules/android_binary/r8_integration/java/com/neverlink:android_binary_with_neverlink_deps"],
)

sh_library(
    name = "r8_integration_helper",
    testonly = True,
    srcs = ["r8_integration_helper.sh"],
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
    name = "r8_desugaring_integration_test",
    size = "enormous",
    srcs = ["r8_desugaring_integration_test.sh"],
    additional_env_inherit = ["ANDROID_HOME"],
    bazel_binaries = bazel_binaries,
    bazel_version = bazel_binaries.versions.current,
    tags = ["manual"],
    timeout = "eternal",
    deps = [
        ":r8_integration_helper",
        "//test/bashunit",
        "@rules_shell//shell/runfiles",
    ],
)

