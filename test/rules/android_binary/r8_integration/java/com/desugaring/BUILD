load("//rules:rules.bzl", "android_binary", "android_library")

android_library(
    name = "duration_lib",
    srcs = ["DurationUser.java"],
)

android_binary(
    name = "desugaring_app_r8",
    srcs = ["DesugaringActivity.java"],
    manifest = "AndroidManifest.xml",
    proguard_specs = ["proguard.cfg"],
    resource_files = glob(["res/**"]),
    visibility = ["//test/rules/android_binary/r8_integration:__pkg__"],
    deps = [":duration_lib"],
)
