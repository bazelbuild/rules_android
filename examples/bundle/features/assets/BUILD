load("@rules_android//android:rules.bzl", "android_library")
load("@rules_android//rules:rules.bzl", "android_feature_module")

android_library(
    name = "lib",
    srcs = ["src/FeatureActivity.java"],
    assets = ["src/assets.txt"],
    custom_package = "com.example.bundle.features.assets",
    manifest = "src/AndroidManifest.xml",
)

android_feature_module(
    name = "feature_module",
    custom_package = "com.example.bundle.features.assets",
    feature_name = "asset_feature",
    has_dex = True,
    library = ":lib",
    manifest = "src/AndroidManifest.xml",
    proguard_specs = ["proguard-rules.pro"],
    title = "asset_feature",
    visibility = ["//visibility:public"],
)
