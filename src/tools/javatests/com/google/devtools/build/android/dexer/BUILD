load("@rules_java//java:defs.bzl", "java_import", "java_library", "java_test")

package(
    default_testonly = 1,
    default_visibility = ["//src:__subpackages__"],
)

filegroup(
    name = "srcs",
    testonly = 0,
    srcs = glob(["**"]),
    visibility = ["//src/tools/javatests/com/google/devtools/build/android:__pkg__"],
)

java_import(
    name = "dexbuilder_import",
    jars = [
        "//src/tools/java/com/google/devtools/build/android/r8:dexbuilder_deploy.jar",
    ],
)

# Description:
#   Tests for the DexFileSplitter.
java_library(
    name = "tests",
    srcs = [
        "AllTests.java",
    ] + select({
        "@androidsdk//:has_androidsdk": ["DexFileSplitterTest.java"],
        "//conditions:default": ["NoAndroidSdkStubTest.java"],
    }),
    javacopts = ["-source 8 -target 8"],
    resources = ["testresource.txt"],
    tags = [
        # TODO(#381): Unsupported option --input?
        "manual",
    ],
    deps = [
        ":dexbuilder_import",
        "//src/tools/java/com/google/devtools/build/android/dexer:DexFileSplitter_lib",
        "//src/tools/java/com/google/devtools/build/android/r8:dexbuilder_deploy.jar",
        "@rules_java//java/runfiles",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
        "@rules_android_maven//:org_mockito_mockito_core",
    ],
)

java_library(
    name = "testdata",
    srcs = glob(["testdata/**/*.java"]),
)

java_test(
    name = "AllTests",
    size = "small",
    data = [
        "test_main_dex_list.txt",
        ":mixed_testinput",
        ":testdata",
        ":tests",
    ],
    jvm_flags = [
        "-Dtestmaindexlist=io_bazel/$(location :test_main_dex_list.txt)",
        "-Dtestinputjar=io_bazel/$(location :tests)",
        "-Dtestinputjar2=io_bazel/$(location :testdata)",
        "-Dmixedinputjar=io_bazel/$(location :mixed_testinput)",
    ],
    tags = [
        # TODO(#381): Unsupported option --input?
        "manual",
    ],
    runtime_deps = [
        ":tests",
    ],
)

genrule(
    name = "mixed_srcjar_gen",
    outs = ["mixed.srcjar"],
    cmd = """set -eu
        readonly tmpdir="$$(mktemp -d)"
        echo "package j$$.test; public class Foo {}" > "$${tmpdir}/Foo.java"
        echo "package zzz; public class Bar {}" > "$${tmpdir}/Bar.java"
        echo "package aaa; public class Baz {}" > "$${tmpdir}/Baz.java"
        $(location @bazel_tools//tools/zip:zipper) c $@ \\
            "j$$/test/Foo.java=$${tmpdir}/Foo.java" \\
            "zzz/Bar.java=$${tmpdir}/Bar.java" \\
            "aaa/Baz.java=$${tmpdir}/Baz.java"
        rm -rf "$${tmpdir}" """,
    tools = ["@bazel_tools//tools/zip:zipper"],
)

java_library(
    name = "mixed_testinput",
    srcs = [":mixed_srcjar_gen"],
)
