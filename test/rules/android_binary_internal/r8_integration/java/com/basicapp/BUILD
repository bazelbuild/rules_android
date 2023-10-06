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
        visibility = ["//test/rules/android_binary_internal/r8_integration:__pkg__"],
        deps = [
            ":basic_lib",
            ":lib_with_specs",
        ],
    )
    for name, specs, shrink in [
        (
            "basic_app_R8_shrink",
            ["proguard.cfg"],
            True,
        ),
        (
            "basic_app_R8_no_shrink",
            ["proguard.cfg"],
            False,
        ),
        ("basic_app_no_R8", [], False),
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
