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

load("defs_dev.bzl", "rules_android_workspace")

rules_android_workspace()

load("@bazel_tools//tools/android:android_extensions.bzl", "android_external_repository")
android_external_repository(
    name = "android_external",
    has_androidsdk = "@androidsdk//:has_androidsdk",
    dx_jar_import = "@androidsdk//:dx_jar_import",
    android_sdk_for_testing = "@androidsdk//:files",
)

register_toolchains("//toolchains/android:all")

register_toolchains("//toolchains/android_sdk:all")

register_toolchains("//toolchains/emulator:all")
