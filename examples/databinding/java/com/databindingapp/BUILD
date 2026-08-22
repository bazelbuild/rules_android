load("@rules_android//android:rules.bzl", "android_binary", "android_library")

android_binary(
    name = "databindingapp",
    manifest = "AndroidManifest.xml",
    enable_data_binding = True,
    deps = [
        ":databinding_lib",
        "@maven//:androidx_databinding_databinding_runtime",
    ],
)

android_library(
    name = "databinding_lib",
    srcs = ["DataBindingMainActivity.java"],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    enable_data_binding = True,
    deps = [
        "@maven//:androidx_annotation_annotation_jvm",
        "@maven//:androidx_databinding_databinding_adapters",
        "@maven//:androidx_databinding_databinding_runtime",
    ],
)
