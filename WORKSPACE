workspace(name = "rules_android")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

load("prereqs.bzl", "rules_android_prereqs")

# Required by protobuf and rules_proto
BAZEL_FEATURES_VERSION = "1.20.0"
BAZEL_FEATURES_HASH = "c2596994cf63513bd44180411a4ac3ae95d32bf59148fcb6087a4642b3ffef11"
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

http_archive(
    name = "rules_java",
    urls = [
        "https://github.com/bazelbuild/rules_java/releases/download/8.3.0/rules_java-8.3.0.tar.gz",
    ],
    sha256 = "c7bd858a132c7b8febe040a90fa138c2e3e7f0bce47122ac2ad43906036a276c",
)
load("@rules_java//java:repositories.bzl", "rules_java_dependencies", "rules_java_toolchains")
rules_java_dependencies()
rules_java_toolchains()

load("defs_dev.bzl", "rules_android_workspace")

rules_android_workspace()

load("//rules:rules.bzl", "android_sdk_repository")

maybe(
    android_sdk_repository,
    name = "androidsdk",
)

register_toolchains("//toolchains/android:all")

register_toolchains("//toolchains/android_sdk:all")
