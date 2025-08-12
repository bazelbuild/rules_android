load("//rules:rules.bzl", "android_binary", "android_library")

[
    android_binary(
        name = name,
        srcs = ["BasicActivity.java"],
        # Work around --java_runtime_version=17 and --java_language_version=11
        # set in the presubmit tests.
        javacopts = [
            "-target",
            "8",
            "-source",
            "8",
        ],
        manifest = "AndroidManifest.xml",
        proguard_specs = specs,
        resource_files = glob(["res/**"]),
        shrink_resources = shrink,
        proguard_generate_mapping = genmap,
        visibility = ["//test/rules/android_binary/r8_integration:__pkg__"],
        deps = [
            ":basic_lib",
            ":lib_with_specs",
        ],
    )
    for name, specs, shrink, genmap in [
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
            "basic_app_select_R8_genmap",
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

config_setting(
    name = "is_c_opt",
    values = {
        "compilation_mode": "opt",
    },
)
