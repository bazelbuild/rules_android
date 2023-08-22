workspace(name = "build_bazel_rules_android")

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load(":android_sdk_supplemental_repository.bzl", "android_sdk_supplemental_repository")

maybe(
    android_sdk_repository,
    name = "androidsdk",
)

maybe(
    android_ndk_repository,
    name = "androidndk",
)

# This can be removed once https://github.com/bazelbuild/bazel/commit/773b50f979b8f40e73cf547049bb8e1114fb670a
# is released, or android_sdk_repository is properly Starlarkified and dexdump
# added there.
android_sdk_supplemental_repository(name = "androidsdk-supplemental")

load("prereqs.bzl", "rules_android_prereqs")
rules_android_prereqs()

load("defs.bzl", "rules_android_workspace")

rules_android_workspace()

register_toolchains("//toolchains/android:all")
register_toolchains("//toolchains/android_sdk:all")
register_toolchains("//toolchains/emulator:all")
