workspace(name = "rules_android")

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

load("prereqs.bzl", "rules_android_prereqs")

# Required by rules_proto.
BAZEL_FEATURES_VERSION = "1.9.1"
BAZEL_FEATURES_HASH = "d7787da289a7fb497352211ad200ec9f698822a9e0757a4976fd9f713ff372b3"
maybe(
    http_archive,
    name = "bazel_features",
    sha256 = BAZEL_FEATURES_HASH,
    strip_prefix = "bazel_features-" + BAZEL_FEATURES_VERSION,
    url = "https://github.com/bazel-contrib/bazel_features/releases/download/v" + BAZEL_FEATURES_VERSION + "/bazel_features-v" + BAZEL_FEATURES_VERSION + ".tar.gz",
)
maybe(
    http_archive,
    name = "proto_bazel_features",
    sha256 = BAZEL_FEATURES_HASH,
    strip_prefix = "bazel_features-" + BAZEL_FEATURES_VERSION,
    url = "https://github.com/bazel-contrib/bazel_features/releases/download/v" + BAZEL_FEATURES_VERSION + "/bazel_features-v" + BAZEL_FEATURES_VERSION + ".tar.gz",
)
load("@bazel_features//:deps.bzl", "bazel_features_deps")
bazel_features_deps()

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
