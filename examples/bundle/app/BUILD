load("@rules_android//android:rules.bzl", "android_application", "android_library")

android_application(
    name = "assets",
    manifest_values = {
        "applicationId" : "com.examples.bundle.app",
        "versionCode": "0",
    },
    feature_modules = ["//features/assets:feature_module"],
    manifest = "AndroidManifest.xml",
    deps = [":lib"],
)

android_library(
    name = "lib",
    srcs = ["BasicActivity.java"],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
)
