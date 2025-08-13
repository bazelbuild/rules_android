# Sample app to demonstrate proper rule structuring and mobile-install usage.

load("//rules:rules.bzl", "android_binary", "android_library")

package(default_visibility = ["//src:__subpackages__"])

android_binary(
    name = "sampleapp",
    manifest = "AndroidManifest.xml",
    multidex = "native",
    deps = [
        ":lib",
    ],
)

android_library(
    name = "lib",
    srcs = glob(["*.java"]),
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    deps = [
        ":native",
    ],
)

# Somewhat annoying hack: explicitly copy the JDK's JNI header and pass
# it as a dep to the cc_library below. This prevents commands such as
# `bazel build src/...` from breaking while attempgint to build the
# JNI target.
genrule(
    name = "jni_h",
    srcs = ["@rules_java//toolchains:jni_header"],
    outs = [":jni.h"],
    cmd = "cp $< $@",
)

genrule(
    name = "jni_md_h",
    srcs = select({
        "//conditions:default": ["@rules_java//toolchains:jni_md_header-linux"],
        "@platforms//os:windows": ["@rules_java//toolchains:jni_md_header-windows"],
        "@platforms//os:macos": ["@rules_java//toolchains:jni_md_header-darwin"],
    }),
    outs = [":jni_md.h"],
    cmd = "cp $< $@",
)

cc_library(
    name = "native",
    srcs = [
        "native.c",
        ":jni.h",
        ":jni_md.h",
    ],
    includes = ["."],
)
