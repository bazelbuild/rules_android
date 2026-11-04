load("//rules:rules.bzl", "android_application", "android_binary", "android_feature_module", "android_library")

[
    android_binary(
        name = name,
        srcs = ["BasicActivity.java"],
        manifest = "AndroidManifest.xml",
        proguard_generate_mapping = generate_pg_map,
        proguard_specs = specs,
        resource_files = glob(["res/**"]),
        shrink_resources = shrink,
        visibility = ["//test/rules/android_binary/r8_integration:__pkg__"],
        deps = [
            ":basic_lib",
            ":lib_with_specs",
        ],
    )
    for name, specs, shrink, generate_pg_map in [
        (
            "basic_app_R8_shrink",
            ["proguard.cfg"],
            True,
            False,
        ),
        (
            "basic_app_R8_no_shrink",
            ["proguard.cfg"],
            False,
            False,
        ),
        (
            "basic_app_no_R8",
            [],
            False,
            False,
        ),
        (
            "basic_app_select_R8_generate_pg_map",
            select({
                ":is_c_opt": ["proguard.cfg"],
                "//conditions:default": [],
            }),
            True,
            True,
        ),
    ]
]

android_library(
    name = "basic_lib",
    srcs = ["UnusedActivity.java"],
    manifest = "AndroidManifest_lib.xml",
    resource_files = glob(["res_lib/**"]),
)

android_library(
    name = "lib_with_specs",
    srcs = ["LibWithSpecsActivity.java"],
    manifest = "AndroidManifest_lib.xml",
    proguard_specs = ["lib_proguard.cfg"],
    deps = [":lib2_with_specs"],
)

android_library(
    name = "lib2_with_specs",
    srcs = ["Lib2WithSpecsActivity.java"],
    manifest = "AndroidManifest_lib.xml",
    proguard_specs = ["lib2_proguard.cfg"],
)

android_binary(
    name = "basic_app_R8_feature_split",
    srcs = ["BasicActivity.java"],
    feature_modules = [":basic_feature"],
    manifest = "AndroidManifest.xml",
    proguard_specs = ["proguard.cfg"],
    resource_files = glob(["res/**"]),
    visibility = ["//test/rules/android_binary/r8_integration:__pkg__"],
    deps = [
        ":basic_lib",
        ":shared_lib",
    ],
)

android_application(
    name = "basic_app_bundle_feature_split",
    srcs = ["BasicActivity.java"],
    feature_modules = ["//test/rules/android_binary/r8_integration/java/com/basicapp:basic_feature"],
    manifest = "AndroidManifest.xml",
    manifest_values = {
        "applicationId": "com.basicapp",
        "versionCode": "1",
    },
    proguard_specs = ["proguard.cfg"],
    resource_files = glob(["res/**"]),
    # The feature's title is only referenced from its manifest and must survive.
    shrink_resources = True,
    visibility = ["//test/rules/android_binary/r8_integration:__pkg__"],
    deps = [
        ":basic_lib",
        ":shared_lib",
    ],
)

android_feature_module(
    name = "basic_feature",
    has_code = True,
    library = ":basic_feature_lib",
    manifest = "FeatureAndroidManifest.xml",
    title = "Basic feature",
)

android_library(
    name = "basic_feature_lib",
    srcs = ["FeatureActivity.java"],
    manifest = "AndroidManifest_lib.xml",
    proguard_specs = ["feature_proguard.cfg"],
    deps = [":shared_lib"],
)

android_library(
    name = "shared_lib",
    srcs = ["SharedHelper.java"],
    manifest = "AndroidManifest_lib.xml",
)

config_setting(
    name = "is_c_opt",
    values = {
        "compilation_mode": "opt",
    },
)
