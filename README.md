# Android support in Bazel

## Disclaimer

NOTE: This branch contains a development preview of the Starlark implementation of Android rules for Bazel. This code is incomplete and may not function as-is.

A version of Bazel built at or near head and the following flags are necessary to use these rules:
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
To use the new Bazel Android rules, add the following to your WORKSPACE file:

    load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
    http_archive(
        name = "build_bazel_rules_android",
        urls = ["https://github.com/bazelbuild/rules_android/archive/refs/heads/pre-alpha.zip"],
        strip_prefix = "rules_android-pre-alpha",
    )
    load("@build_bazel_rules_android//:defs.bzl", "rules_android_workspace")
    rules_android_workspace()
    
    register_toolchains(
      "@build_bazel_rules_android//toolchains/android:android_default_toolchain",
      "@build_bazel_rules_android//toolchains/android_sdk:android_sdk_tools",
    )


Then, in your BUILD files, import and use the rules:

    load("@build_bazel_rules_android//rules:rules.bzl", "android_library")
    android_library(
        ...
    )
