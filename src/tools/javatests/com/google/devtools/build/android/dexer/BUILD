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
    deps = [
        ":dexbuilder_import",
        "//src/tools/java/com/google/devtools/build/android/dexer:DexFileSplitter_lib",
        "//src/tools/java/com/google/devtools/build/android/r8:dexbuilder_deploy.jar",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
        "@rules_android_maven//:org_mockito_mockito_core",
        "@rules_java//java/runfiles",
    ],
)

java_library(
    name = "testdata",
    srcs = glob(["testdata/**/*.java"]),
)

java_test(
    name = "AllTests",
    size = "small",
    srcs = ["AllTests.java"],
    data = [
        ":jsimple_jar",
        ":multidex_jar",
        ":simple_jar",
    ],
    jvm_flags = [
        "-Djsimplejar=$(rlocationpath :jsimple_jar)",
        "-Dmultidexjar=$(rlocationpath :multidex_jar)",
        "-Dsimplejar=$(rlocationpath :simple_jar)",
    ],
    runtime_deps = [
        ":tests",
    ],
    deps = [
        ":tests",
        "@rules_android_maven//:junit_junit",
    ],
)

genrule(
    name = "jsimple_jar_gen",
    outs = ["jsimple.srcjar"],
    cmd = """set -eu
        readonly tmpdir="$$(mktemp -d)"
        echo "package j$$; public class Foo {}" > "$${tmpdir}/Foo.java"
        $(location //tools/jdk:singlejar) --output $@ --resources "$${tmpdir}/Foo.java:j$$/test/Foo.java"
        rm -rf "$${tmpdir}" """,
    tools = ["//tools/jdk:singlejar"],
)

java_library(
    name = "jsimple_jar",
    srcs = [":jsimple_jar_gen"],
)

genrule(
    name = "simple_jar_gen",
    outs = ["simple.srcjar"],
    cmd = """set -eu
        readonly tmpdir="$$(mktemp -d)"
        echo "package base; public class SimpleClass { public int field; public void method() {} }" > "$${tmpdir}/SimpleClass.java"
        $(location //tools/jdk:singlejar) --output $@ --resources "$${tmpdir}/SimpleClass.java:base/SimpleClass.java"
        rm -rf "$${tmpdir}" """,
    tools = ["//tools/jdk:singlejar"],
)

java_library(
    name = "simple_jar",
    srcs = [":simple_jar_gen"],
)

genrule(
    name = "multidex_jar_gen",
    outs = ["multidex.srcjar"],
    cmd = """set -eu
        readonly tmpdir="$$(mktemp -d)"
        for i in $$(seq 1 4); do
          echo "package multidex; public class Class$${i} {" > "$${tmpdir}/Class$${i}.java"
          for j in $$(seq 1 60); do
            echo "  public void method$${j}() {}" >> "$${tmpdir}/Class$${i}.java"
          done
          echo "}" >> "$${tmpdir}/Class$${i}.java"
        done
        args=""
        for f in "$${tmpdir}"/*.java; do
          args+=" $${f}:multidex/$$(basename "$${f}")"
        done
        $(location //tools/jdk:singlejar) --output $@ --resources $${args}
        rm -rf "$${tmpdir}" """,
    tools = ["//tools/jdk:singlejar"],
)

java_library(
    name = "multidex_jar",
    srcs = [":multidex_jar_gen"],
)
