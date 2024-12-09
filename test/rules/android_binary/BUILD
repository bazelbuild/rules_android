load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_java//java:java_library.bzl", "java_library")
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

genrule(
    name = "native_cc",
    outs = ["native.cc"],
    cmd = "echo 'int native() {return 0;}' > $@",
)

cc_library(
    name = "native_lib",
    srcs = ["native.cc"],
    toolchains = [
        ":fake_arm64-v8a_toolchain",
        ":fake_armeabi-v7a_toolchain",
    ],
)

genrule(
    name = "Foo_java",
    outs = ["Foo.java"],
    cmd = "echo 'package com.example; public class Foo {}' > $@",
)

java_library(
    name = "Foo_java_lib",
    srcs = ["Foo.java"],
    deps = [":native_lib"],
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

android_library(
    name = "basiclib_with_native_dep",
    srcs = [
        "java/com/foo/AJavaClass.java",
        "java/com/foo/AndroidManifest.xml",
    ],
    deps = [":native_lib"],
)

android_binary(
    name = "basicapp_with_native_dep_from_java_lib",
    srcs = ["java/com/binary/AJavaClass.java"],
    custom_package = "com.binary",
    manifest = "AndroidManifest.xml",
    resource_files = ["res/layout/main.xml"],
    deps = [":basiclib_with_native_dep"],
)

genrule(
    name = "so_file_from_app",
    srcs = [":basicapp_with_native_dep_from_java_lib.apk"],
    outs = ["lib_from_app.so"],
    cmd = "set -e; unzip -q $(SRCS); find lib -name \"*.so\" -exec cp {} $@ \\;",
)

build_test(
    name = "so_file_from_app_test",
    size = "small",
    targets = [
        ":so_file_from_app",
    ],
)
