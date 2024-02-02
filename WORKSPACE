workspace(name = "rules_android")

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

load("prereqs.bzl", "rules_android_prereqs")

rules_android_prereqs(dev_mode = True)

load("//rules:rules.bzl", "android_sdk_repository")

maybe(
    android_sdk_repository,
    name = "androidsdk",
)

maybe(
    android_ndk_repository,
    name = "androidndk",
)

load("@rules_python//python:repositories.bzl", "py_repositories")
py_repositories()

load("defs_dev.bzl", "rules_android_workspace")

rules_android_workspace()

register_toolchains("//toolchains/android:all")

register_toolchains("//toolchains/android_sdk:all")

register_toolchains("//toolchains/emulator:all")
