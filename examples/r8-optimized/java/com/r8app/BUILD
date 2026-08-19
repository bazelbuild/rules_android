load(
    "@rules_android//android:rules.bzl",
    "android_library",
)

exports_files([
    "AndroidManifest.xml",
    "bundle_config.pb.json",
])

android_library(
    name = "r8_lib",
    srcs = ["MainActivity.java"],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    visibility = ["//:__pkg__"],
)
