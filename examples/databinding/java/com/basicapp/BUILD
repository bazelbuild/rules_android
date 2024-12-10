load("@rules_android//android:rules.bzl", "android_binary", "android_library")

android_binary(
    name = "basic_app",
    manifest = "AndroidManifest.xml",
    deps = [":basic_lib"],
    enable_data_binding = True,
)

android_library(
    name = "basic_lib",
    srcs = ["BasicActivity.java"],
    javacopts = ["-source 11 -target 11"],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    enable_data_binding = True,
)
