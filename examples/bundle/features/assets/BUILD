load("@rules_android//rules:rules.bzl", "android_library", "android_feature_module")

android_library(
    name = "lib",
    manifest = "src/AndroidManifest.xml",
    assets = ["src/assets.txt"],
)

android_feature_module(
    name = "feature_module",
    custom_package = "com.example.bundle.features.assets",
    manifest = "src/AndroidManifest.xml",
    title = "asset_feature",
    library = ":lib",
    feature_name = "asset_feature",
    visibility = ["//visibility:public"],
)
