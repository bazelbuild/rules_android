load("@rules_android//android:rules.bzl", "android_library")
load("@rules_android//rules:rules.bzl", "android_feature_module")

android_library(
    name = "lib",
    custom_package = "com.examples.bundle.native",
    manifest = "src/AndroidManifest.xml",
    deps = [
        "@maven//:com_arthenica_ffmpeg_kit_https"
    ]
)

android_feature_module(
    name = "feature_module",
    custom_package = "com.examples.bundle.features.native",
    manifest = "src/AndroidManifest.xml",
    title = "native_feature",
    library = ":lib",
    feature_name = "native_feature",
    visibility = ["//visibility:public"],
)