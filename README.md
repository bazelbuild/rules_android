# Android support in Bazel

## Disclaimer

NOTE: This branch is a development preview of the Starlark implementation of Android rules for Bazel. This code is incomplete and may not function as-is.

A version of Bazel built at or near head or a recent pre-release and the following flags are necessary to use these rules:

```
--experimental_enable_android_migration_apis
--experimental_google_legacy_api
```

## Overview

This repository contains the Starlark implementation of Android rules in Bazel.

The rules are being incrementally converted from their native implementations
in the [Bazel source
tree](https://source.bazel.build/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/android/).

Stardoc for the Android rules can be found at
[https://bazelbuild.github.io/rules_android](https://bazelbuild.github.io/rules_android/).

## Getting Started
To use the Starlark Bazel Android rules, add the following to your WORKSPACE file:


```starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
http_archive(
    name = "rules_android",
    sha256 = "fe3d8c4955857b44019d83d05a0b15c2a0330a6a0aab990575bb397e9570ff1b",
    strip_prefix = "rules_android-0.6.0-alpha1",
    url = "https://github.com/bazelbuild/rules_android/releases/download/v0.6.0-alpha1/rules_android-v0.6.0-alpha1.tar.gz",
)

# Android rules dependencies
load("@rules_android//:prereqs.bzl", "rules_android_prereqs")
rules_android_prereqs()

##### rules_java setup for rules_android #####
load("@rules_java//java:rules_java_deps.bzl", "rules_java_dependencies")
rules_java_dependencies()
# note that the following line is what is minimally required from protobuf for the java rules
# consider using the protobuf_deps() public API from @com_google_protobuf//:protobuf_deps.bzl
load("@com_google_protobuf//bazel/private:proto_bazel_features.bzl", "proto_bazel_features")  # buildifier: disable=bzl-visibility
proto_bazel_features(name = "proto_bazel_features")
# register toolchains
load("@rules_java//java:repositories.bzl", "rules_java_toolchains")
rules_java_toolchains()

##### rules_jvm_external setup for rules_android #####
load("@rules_jvm_external//:repositories.bzl", "rules_jvm_external_deps")
rules_jvm_external_deps()
load("@rules_jvm_external//:setup.bzl", "rules_jvm_external_setup")
rules_jvm_external_setup()

##### rules_android setup #####
load("@rules_android//:defs.bzl", "rules_android_workspace")
rules_android_workspace()

# Android SDK setup
load("@rules_android//rules:rules.bzl", "android_sdk_repository")
android_sdk_repository(
    name = "androidsdk",
)

register_toolchains(
    "@rules_android//toolchains/android:android_default_toolchain",
    "@rules_android//toolchains/android_sdk:android_sdk_tools",
)
```


Or, if you want to use bzlmod, add the following to your MODULE.bazel file:

MODULE.bazel:

```starlark
bazel_dep(name = "rules_java", version = "7.11.1")
bazel_dep(name = "bazel_skylib", version = "1.3.0")

bazel_dep(name = "rules_android", version = "0.6.5")

remote_android_extensions = use_extension(
    "@rules_android//bzlmod_extensions:android_extensions.bzl",
    "remote_android_tools_extensions")
use_repo(remote_android_extensions, "android_tools")

android_sdk_repository_extension = use_extension("@rules_android//rules/android_sdk_repository:rule.bzl", "android_sdk_repository_extension")
use_repo(android_sdk_repository_extension, "androidsdk")

register_toolchains("@androidsdk//:sdk-toolchain", "@androidsdk//:all")
```



Then, in your BUILD files, import and use the rules:

```starlark
load("@rules_android//rules:rules.bzl", "android_binary", "android_library")
android_binary(
    ...
)

android_library(
   ...
)
```
