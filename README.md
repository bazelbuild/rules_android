# Android support in Bazel

## Deprecation notice

The `master` branch of https://github.com/bazelbuild/rules_android is now
deprecated. Active development has been moved to [the 'main' branch](https://github.com/bazelbuild/rules_android/tree/main).
We will leave this branch up for posterity.

## Overview

This repository contains the Skylark implementation of Android rules in Bazel.

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

    load("@build_bazel_rules_android//android:rules.bzl", "android_library")
    android_library(
        ...
    )
