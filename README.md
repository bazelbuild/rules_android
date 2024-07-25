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
    sha256 = "fc6b022e97c2d5893aa3dd01b480f37cd386d82fc7e14edbcba393cd390a244e",
    strip_prefix = "rules_android-0.5.0",
    url = "https://github.com/bazelbuild/rules_android/releases/download/v0.5.0/rules_android-v0.5.0.tar.gz",
)
load("@rules_android//:prereqs.bzl", "rules_android_prereqs")
rules_android_prereqs()
load("@rules_android//:defs.bzl", "rules_android_workspace")
rules_android_workspace()

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
bazel_dep(name = "rules_java", version = "7.7.0")
bazel_dep(name = "bazel_skylib", version = "1.3.0")

bazel_dep(name = "rules_android", version = "0.5.0.bcr.1")
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