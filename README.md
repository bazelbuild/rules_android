# Android support in Bazel

## Disclaimer

NOTE: This branch is a development preview of the Starlark implementation of Android rules for Bazel. This code is incomplete and may not function as-is.

A version of Bazel built at or near head or a recent pre-release and the following flags are necessary to use these rules:

```
--experimental_enable_android_migration_apis
--experimental_google_legacy_api
--incompatible_java_common_parameters
--android_databinding_use_v3_4_args
--experimental_android_databinding_v2
```

## Overview

This repository contains the Starlark implementation of Android rules in Bazel.

The rules are being incrementally converted from their native implementations
in the [Bazel source
tree](https://source.bazel.build/bazel/+/master:src/main/java/com/google/devtools/build/lib/rules/android/).

For the list of Android rules, see the Bazel [documentation](https://docs.bazel.build/versions/master/be/android.html).

## Getting Started
To use the Starlark Bazel Android rules, add the following to your WORKSPACE file:

    load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

    # Or a later commit
    RULES_ANDROID_COMMIT= "0bf3093bd011acd35de3c479c8990dd630d552aa"
    RULES_ANDROID_SHA = "b75a673a66c157138ab53f4d8612a6e655d38b69bb14207c1a6675f0e10afa61"
    http_archive(
        name = "build_bazel_rules_android",
        url = "https://github.com/bazelbuild/rules_android/archive/%s.zip" % RULES_ANDROID_COMMIT,
        sha256 = RULES_ANDROID_SHA,
        strip_prefix = "rules_android-%s" % RULES_ANDROID_COMMIT,
    )
    load("@build_bazel_rules_android//:prereqs.bzl", "rules_android_prereqs")
    rules_android_prereqs()
    load("@build_bazel_rules_android//:defs.bzl", "rules_android_workspace")
    rules_android_workspace()

    register_toolchains(
    "@build_bazel_rules_android//toolchains/android:android_default_toolchain",
    "@build_bazel_rules_android//toolchains/android_sdk:android_sdk_tools",
    )

Then, in your BUILD files, import and use the rules:

    load("@build_bazel_rules_android//rules:rules.bzl", "android_binary", "android_library")
    android_binary(
        ...
    )

    android_library(
        ...
    )
