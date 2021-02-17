# Android support in Bazel

## Disclaimer

NOTE: This branch contains a development preview of the Starlark implementation of Android rules for Bazel. This code is incomplete and may not function as-is.

Bazel 4.0.0 or newer and the following flags are necessary to use these rules:
```
--experimental_enable_android_migration_apis
--experimental_google_legacy_api
--incompatible_java_common_parameters
--android_databinding_use_v3_4_args
--experimental_android_databinding_v2
```

Also, register the Android toolchains in the `WORKSPACE` file with:
```
register_toolchains(
  "@build_bazel_rules_android//toolchains/android:android_default_toolchain",
  "@build_bazel_rules_android//toolchains/android_sdk:android_sdk_tools",
)
```
(Assuming that the Android rules repository in the `WORKSPACE` file is named `build_bazel_rules_android`.)

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
        urls = ["https://github.com/bazelbuild/rules_android/archive/v0.1.1.zip"],
        sha256 = "cd06d15dd8bb59926e4d65f9003bfc20f9da4b2519985c27e190cddc8b7a7806",
        strip_prefix = "rules_android-0.1.1",
    )

Then, in your BUILD files, import and use the rules:

    load("@build_bazel_rules_android//rules:rules.bzl", "android_library")
    android_library(
        ...
    )
