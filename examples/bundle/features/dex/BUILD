load("@rules_android//android:rules.bzl", "android_library")
load("@rules_android//rules:rules.bzl", "android_feature_module")

android_library(
    name = "lib",
    srcs = glob(["src/main/*.java"]),
    custom_package = "com.examples.bundle.features.dex",
    manifest = "src/AndroidManifest.xml",
    deps = [
        "@maven//:com_google_guava_guava",
    ]
)

android_feature_module(
    name = "feature_module",
    custom_package = "com.examples.bundle.features.dex",
    manifest = "src/AndroidManifest.xml",
    title = "dex_feature",
    library = ":lib",
    feature_name = "dex_feature",
    visibility = ["//visibility:public"],
)