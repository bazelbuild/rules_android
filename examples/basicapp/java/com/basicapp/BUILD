load(
    "@rules_android//android:rules.bzl",
     "android_binary",
     "android_library",
     "android_application",
)

android_binary(
    name = "basic_app",
    manifest = "AndroidManifest.xml",
    deps = [":basic_lib"],
)

android_library(
    name = "basic_lib",
    srcs = ["BasicActivity.java"],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
)

android_application(
    name = "basic_app_bundle",
    # bundle_config_file or feature_modules must be specified to get an aab
    bundle_config_file = "bundle_config.pb.json",
    manifest = "AndroidManifest.xml",
    manifest_values = {
        "applicationId": "com.basicapp",
        "versionCode": "1",
    },
    deps = [":basic_lib"],
)
