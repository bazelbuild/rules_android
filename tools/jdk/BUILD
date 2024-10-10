load("@rules_java//toolchains:default_java_toolchain.bzl", "default_java_toolchain")

default_java_toolchain(
    name = "toolchain_android_only",
    bootclasspath = [
        "//tools/android:android_jar",
        # TODO(b/175805830): Add this only when desugaring is enabled.
        "//tools/android:desugar_java8_extra_bootclasspath",
    ],
    visibility = ["//visibility:public"],
)

alias(
    name = "toolchain",
    actual = "@rules_java//toolchains:toolchain",
    visibility = ["//visibility:public"],
)

alias(
    name = "current_java_runtime",
    actual = "@rules_java//toolchains:current_java_runtime",
    visibility = ["//visibility:public"],
)

alias(
    name = "current_java_toolchain",
    actual = "@rules_java//toolchains:current_java_toolchain",
    visibility = ["//visibility:public"],
)

alias(
    name = "jdk",
    actual = "@bazel_tools//tools/jdk:jdk",
    visibility = ["//visibility:public"],
)

alias(
    name = "current_host_java_runtime",
    actual = "@rules_java//toolchains:current_host_java_runtime",
    visibility = ["//visibility:public"],
)
