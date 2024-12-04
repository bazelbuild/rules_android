load("//rules:rules.bzl", "android_binary", "android_library")
load(":test.bzl", "fake_cc_toolchain_config", "multiple_android_platforms_test")

filegroup(name = "empty")

fake_cc_toolchain_config(
    name = "fake_cc_toolchain_config",
)

cc_toolchain(
    name = "fake_cc_toolchain",
    all_files = ":empty",
    compiler_files = ":empty",
    dwp_files = ":empty",
    linker_files = ":empty",
    objcopy_files = ":empty",
    strip_files = ":empty",
    supports_param_files = 0,
    toolchain_config = ":fake_cc_toolchain_config",
    toolchain_identifier = "linux_x86_64-toolchain",
)

toolchain(
    name = "fake_arm64-v8a_toolchain",
    target_compatible_with = [
        "@platforms//os:android",
        "@platforms//cpu:aarch64",
    ],
    toolchain = ":fake_cc_toolchain",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

toolchain(
    name = "fake_armeabi-v7a_toolchain",
    target_compatible_with = [
        "@platforms//os:android",
        "@platforms//cpu:armv7",
    ],
    toolchain = ":fake_cc_toolchain",
    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
)

android_binary(
    name = "basicapp",
    srcs = ["java/com/binary/AJavaClass.java"],
    custom_package = "com.binary",
    manifest = "AndroidManifest.xml",
    resource_files = ["res/layout/main.xml"],
    deps = [":basiclib"],
)

android_library(
    name = "basiclib",
    srcs = ["java/com/foo/AJavaClass.java"],
)

multiple_android_platforms_test(
    name = "multiple_android_platforms_test",
    target_under_test = ":basicapp",
)
