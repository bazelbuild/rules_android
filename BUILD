load("@bazel_gazelle//:def.bzl", "gazelle")

package(default_visibility = ["//visibility:public"])

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
