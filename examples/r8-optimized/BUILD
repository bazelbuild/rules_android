load(
    "@rules_android//android:rules.bzl",
    "android_application",
    "android_binary",
)

android_binary(
    name = "r8_app",
    custom_package = "com.r8app",
    manifest = "//java/com/r8app:AndroidManifest.xml",
    proguard_generate_mapping = True,
    proguard_specs = [
        "proguard-android-optimize.txt",
        "proguard-rules.pro",
    ],
    shrink_resources = True,
    deps = ["//java/com/r8app:r8_lib"],
)

android_application(
    name = "r8_app_bundle",
    # bundle_config_file or feature_modules must be specified to get an aab
    bundle_config_file = "//java/com/r8app:bundle_config.pb.json",
    manifest = "//java/com/r8app:AndroidManifest.xml",
    manifest_values = {
        "applicationId": "com.r8app",
        "versionCode": "1",
    },
    deps = ["//java/com/r8app:r8_lib"],
)
