load("//rules/android_library:rule.bzl", "android_library")
load("//rules/fat_aar:rule.bzl", "fat_aar")

# Library with resources and assets
android_library(
    name = "lib1",
    srcs = ["Lib1.java"],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    assets = glob(["assets/**"]),
    assets_dir = "assets",
)

# Library depending on lib1 (transitive dependency test)
android_library(
    name = "lib2",
    srcs = ["Lib2.java"],
    manifest = "AndroidManifest.xml",
    deps = [":lib1"],
)

# Native library
cc_library(
    name = "native_lib",
    srcs = ["jni/arm64-v8a/libnative.so"],
)

# Fat AAR bundling all transitive dependencies
fat_aar(
    name = "bundled",
    min_sdk_version = "21",
    deps = [
        ":lib2",
        ":native_lib",
    ],
)

# Fat AAR with exclusions (e.g., exclude external dependencies)
fat_aar(
    name = "bundled_filtered",
    min_sdk_version = "21",
    exclude = ["@maven//"],
    deps = [":lib2"],
)
