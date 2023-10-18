# Sample app to demonstrate proper rule structuring and mobile-install usage.

load("//rules:rules.bzl", "android_binary", "android_library")

package(default_visibility = ["//src:__subpackages__"])

android_binary(
    name = "sampleapp",
    manifest = "AndroidManifest.xml",
    multidex = "native",
    deps = [
        ":lib",
    ],
)

android_library(
    name = "lib",
    srcs = glob(["*.java"]),
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    deps = [
        ":native",
    ],
)

cc_library(
    name = "native",
    srcs = ["native.c"],
)
