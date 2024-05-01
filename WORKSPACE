workspace(name = "rules_android")

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

load("prereqs.bzl", "rules_android_prereqs")

rules_android_prereqs(dev_mode = True)

load("//rules:rules.bzl", "android_sdk_repository")

maybe(
    android_sdk_repository,
    name = "androidsdk",
)

load("defs_dev.bzl", "rules_android_workspace")

rules_android_workspace()

register_toolchains("//toolchains/android:all")

register_toolchains("//toolchains/android_sdk:all")
