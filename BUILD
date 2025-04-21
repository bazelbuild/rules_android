load("@bazel_gazelle//:def.bzl", "gazelle")
load("@rules_license//rules:license.bzl", "license")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:public"],
)

license(
    name = "license",
    package_name = "bazelbuild/rules_android",
    copyright_notice = "Copyright © 2023 The Bazel Authors. All rights reserved.",
    license_kinds = [
        "@rules_license//licenses/spdx:Apache-2.0",
    ],
    license_text = "LICENSE",
)

# gazelle:prefix github.com/bazelbuild/rules_android
gazelle(name = "gazelle")

# Common default platform definitions for use by Android projects.

platform(
    name = "x86",
    constraint_values = [
        "@platforms//os:android",
        "@platforms//cpu:x86_32",
    ],
)

platform(
    name = "x86_64",
    constraint_values = [
        "@platforms//os:android",
        "@platforms//cpu:x86_64",
    ],
)

platform(
    name = "armeabi-v7a",
    constraint_values = [
        "@platforms//os:android",
        "@platforms//cpu:armv7",
    ],
)

platform(
    name = "arm64-v8a",
    constraint_values =
        [
            "@platforms//cpu:arm64",
            "@platforms//os:android",
        ],
)

platform(
    name = "riscv64",
    constraint_values =
        [
            "@platforms//cpu:riscv64",
            "@platforms//os:android",
        ],
)

# TODO: remove these alias when we no longer needs bind in WORKSPACE.bzlmod
# Because @androidsdk is not defined in WORKSPACE.bzlmod, where the only valid place
# we can call native function bind. Using these alias to forward the binding.
alias(
    name = "androidsdk_sdk",
    actual = "@androidsdk//:sdk",
)

alias(
    name = "androidsdk_d8_jar_import",
    actual = "@androidsdk//:d8_jar_import",
)

alias(
    name = "androidsdk_dx_jar_import",
    actual = "@androidsdk//:dx_jar_import",
)

alias(
    name = "androidsdk_files",
    actual = "@androidsdk//:files",
)

alias(
    name = "androidsdk_has_android_sdk",
    actual = "@androidsdk//:has_android_sdk",
)

filegroup(
    name = "all_files",
    # Note: The glob pattern here is just '*' and not '**' in order to avoid collecing subdirectories
    # In OSS Bazel-land, subdirectories can include irrelevant files such as .git/, .bazelci/, etc.
    srcs = glob(["*"]) + [
        "//android:all_files",
        "//bzlmod_extensions:all_files",
        "//mobile_install:all_files",
        "//providers:all_files",
        "//rules:all_files",
        "//src/common/golang:all_files",
        "//src/tools/ak:all_files",
        "//src/tools/bundletool_module_builder:all_files",
        "//src/tools/deploy_info:all_files",
        "//src/tools/extract_desugar_pgcfg_flags:all_files",
        "//src/tools/jar_to_module_info:all_files",
        "//src/tools/java/com/google/devtools/build/android:srcs",
        "//src/tools/java_resource_extractor:all_files",
        "//src/tools/jdeps:all_files",
        "//src/tools/mi/deployment_oss:all_files",
        "//src/tools/split_core_jar:all_files",
        "//src/validations/aar_import_checks:all_files",
        "//src/validations/validate_manifest:all_files",
        "//toolchains/android:all_files",
        "//toolchains/android_sdk:all_files",
        "//tools/android:all_files",
        "//tools/jdk:all_files",
    ]
)

genrule(
    name = "all_files_tar",
    srcs = [":all_files"],
    outs = ["all_files.tar"],
    # Note: The "h" in the tar options forces tar to _copy_ the files into
    # the archive, rather than symlink.
    cmd = "tar chf $@ $(locations :all_files)",
)