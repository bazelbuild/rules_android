workspace(name = "build_bazel_rules_android")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

maybe(
    android_sdk_repository,
    name = "androidsdk",
)

maybe(
    android_ndk_repository,
    name = "androidndk",
)

load("prereqs.bzl", "rules_android_prereqs")
rules_android_prereqs()

load("defs.bzl", "rules_android_workspace")

rules_android_workspace()

register_toolchains("//toolchains/android:all")
register_toolchains("//toolchains/android_sdk:all")
register_toolchains("//toolchains/emulator:all")
