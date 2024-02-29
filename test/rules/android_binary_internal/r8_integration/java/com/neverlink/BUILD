load("//rules:rules.bzl", "android_binary", "android_library")
load("//rules/android_binary_internal:rule.bzl", "android_binary_internal")

# For a build_test.
# Note that this app will build, but will not run because the neverlink
# libraries won't be in the app.
android_binary(
    name = "android_binary_with_neverlink_deps",
    srcs = ["BasicActivity.java"],
    manifest = "AndroidManifest.xml",
    proguard_specs = ["proguard.cfg"],
    visibility = ["//test/rules/android_binary_internal/r8_integration:__pkg__"],
    deps = [
        ":neverlink_lib1",
        ":neverlink_lib2",
    ],
)

# Only for analysis-time tests.
android_binary_internal(
    name = "android_binary_internal_with_neverlink_deps",
    srcs = ["BasicActivity.java"],
    manifest = "AndroidManifest.xml",
    proguard_specs = ["proguard.cfg"],
    visibility = ["//test/rules/android_binary_internal/r8_integration:__pkg__"],
    deps = [
        ":neverlink_lib1",
        ":neverlink_lib2",
    ],
)

android_library(
    name = "neverlink_lib1",
    srcs = ["Neverlink1.java"],
    neverlink = True,
)

android_library(
    name = "neverlink_lib2",
    srcs = ["Neverlink2.java"],
    neverlink = True,
)
