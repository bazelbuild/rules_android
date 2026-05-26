load(
    "@rules_android//android:rules.bzl",
     "android_binary",
     "android_library",
     "android_application",
)
load("@rules_java//java:java_library.bzl", "java_library")

genrule(
    name = "proguard_cfg",
    outs = ["proguard.cfg"],
    cmd = "echo > $@",
)

android_binary(
    name = "basic_app",
    manifest = "AndroidManifest.xml",
    deps = [":basic_lib"],
    proguard_specs = [":proguard_cfg"],
)

android_library(
    name = "basic_lib",
    srcs = ["BasicActivity.java"],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    deps = [":basic_dep"],
)

java_library(
    name = "basic_dep",
    srcs = ["BasicDep.java"],
    # manifest = "AndroidManifest.xml",
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
