load("//rules:rules.bzl", "android_binary", "android_library")

android_binary(
    name = "basic_app",
    manifest = "AndroidManifest.xml",
    visibility = ["//test/rules/android_binary/manifest_merge_order:__pkg__"],
    deps = [":basic_lib"],
)

android_library(
    name = "basic_lib",
    manifest = "AndroidManifest.xml",
    # Do not sort: manifest_merge_order_test tests that we don't sort these in the rule code
    deps = [
        ":manifest_ZZZ_foo",
        ":manifest_BBB_bar",
    ],
)

android_library(
    name = "manifest_ZZZ_foo",
    exports_manifest = True,
    manifest = "AndroidManifestFoo.xml",
)

android_library(
    name = "manifest_BBB_bar",
    exports_manifest = True,
    manifest = "AndroidManifestBar.xml",
    deps = [":manifest_AAA_baz"],
)

android_library(
    name = "manifest_AAA_baz",
    exports_manifest = True,
    manifest = "AndroidManifestBaz.xml",
)
