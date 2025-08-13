load("@rules_java//java:java_import.bzl", "java_import")
load("@rules_java//toolchains:default_java_toolchain.bzl", "default_java_toolchain")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//tools/jdk:system.bzl", "android_system")

# Java language versions
# See https://bazel.build/docs/user-manual#java-language-version
_SUPPORTED_JAVA_LANGUAGE_VERSIONS = [
    8,
    9,
    10,
    11,
    17,
    21,
]

[
    config_setting(
        name = "java_language_version_%d" % ver,
        values = {"java_language_version": str(ver)},
    )
    for ver in _SUPPORTED_JAVA_LANGUAGE_VERSIONS
]

java_language_version_select_dict = {
    ":java_language_version_%d" % ver: ":toolchain_android_only_%d" % ver
    for ver in _SUPPORTED_JAVA_LANGUAGE_VERSIONS
} | {
    "//conditions:default": ":toolchain_android_only_11",
}

alias(
    name = "singlejar",
    actual = "@rules_java//toolchains:singlejar",
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "create_system",
    srcs = ["create_system.sh"],
    # Required on Windows to avoid "LAUNCHER ERROR: Rlocation failed", because providing it via
    # the "tools" parameter of ctx.actions.run() doesn't seem to be enough.
    data = ["//tools/android:unzip"],
    visibility = ["//visibility:public"],
)

genrule(
    name = "fake_jar",
    testonly = 1,
    outs = ["fake.jar"],
    cmd = "set -euo pipefail\n" +
          "mkdir -p a/b\n" +
          "mkdir -p c/d\n" +
          "touch a/b/x.class\n" +
          "touch c/d/y.class\n" +
          "touch foobar.txt\n" +
          "zip -q -r $@ a c foobar.txt",
)

sh_test(
    name = "jar_to_module_info_test",
    srcs = ["jar_to_module_info_test.sh"],
    data = [
        "test_module_info_golden.txt",
        ":fake_jar",
        "//src/tools/jar_to_module_info",
    ],
    deps = [
        "@rules_shell//shell/runfiles",
    ],
)

android_system(
    name = "bootclasspath_android_only",
    bootclasspath = [
        "//tools/android:android_jar",
        "//tools/android:desugar_java8_extra_bootclasspath",
    ],
    core_jars = [
        "@androidsdk//:core-for-system-modules-jar",
    ],
)

[
    default_java_toolchain(
        name = "toolchain_android_only_%d" % ver,
        bootclasspath = [
            ":bootclasspath_android_only",
        ],
        source_version = str(ver),
        target_version = str(ver),
        visibility = ["//visibility:public"],
    )
    for ver in _SUPPORTED_JAVA_LANGUAGE_VERSIONS
]

alias(
    name = "toolchain_android_only",
    actual = select(java_language_version_select_dict),
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
    name = "current_host_java_runtime",
    actual = "@rules_java//toolchains:current_host_java_runtime",
    visibility = ["//visibility:public"],
)

java_import(
    name = "TestRunner",
    jars = ["@remote_java_tools//:Runner"],
    visibility = ["//visibility:public"],
)

exports_files(["java_stub_template.txt"])
