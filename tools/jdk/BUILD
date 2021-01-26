load("@bazel_tools//tools/jdk:default_java_toolchain.bzl", "default_java_toolchain")

default_java_toolchain(
    name = "toolchain_android_only",
    bootclasspath = [
        "//tools/android:android_jar",
        # TODO(b/175805830): Add this only when desugaring is enabled.
        "@bazel_tools//tools/android:desugar_java8_extra_bootclasspath",
    ],
    visibility = ["//visibility:public"],
)
