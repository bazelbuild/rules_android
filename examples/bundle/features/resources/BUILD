load("@rules_android//android:rules.bzl", "android_library")
load("@rules_android//rules:rules.bzl", "android_feature_module")

android_library(
    name = "lib",
    custom_package = "com.examples.bundle.resources",
    resource_files = glob(["src/res/**"]),
    manifest = "src/AndroidManifest.xml",
)

android_feature_module(
    name = "feature_module",
    custom_package = "com.examples.bundle.features.resources",
    manifest = "src/AndroidManifest.xml",
    title = "resources_feature",
    library = ":lib",
    feature_name = "resources_feature",
    visibility = ["//visibility:public"],
)