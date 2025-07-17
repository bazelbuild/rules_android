load("//rules:rules.bzl", "android_library")

licenses(["notice"])

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = [
        "//test/rules/resources:__subpackages__",
        "//tools/build_defs/android/test/dev/resources:__pkg__",
    ],
)

android_library(
    name = "A",
    custom_package = "com.google.foo.bar",
    exports_manifest = 1,
    manifest = "AndroidManifest.xml",
)
