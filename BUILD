load("@bazel_gazelle//:def.bzl", "gazelle")
load("@rules_license//rules:license.bzl", "license")

package(
    default_applicable_licenses = [":license"],
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
    name = "androidsdk_files",
    actual = "@androidsdk//:files",
)

alias(
    name = "androidsdk_has_androidsdk",
    actual = "@androidsdk//:has_androidsdk",
)
