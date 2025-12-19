# Tests that run on head android_local_test rule to verify Starlark resource processing pipeline.

load(
    "//rules:rules.bzl",
    "android_library",
    "android_local_test",
)
load(
    "//test/rules/android_local_test:test.bzl",
    "rule_test",
)

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//visibility:private"],
)

licenses(["notice"])

android_local_test(
    name = "no_deps_with_resources",
    srcs = ["SampleTest.java"],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    test_class = "com.starlark_resources.SampleTest",
    deps = [
        "@robolectric//bazel:android-all",
        "@maven//:androidx_test_core",
        "@maven//:androidx_test_ext_junit",
        "@maven//:junit_junit",
        "@maven//:org_robolectric_robolectric",
    ],
)

android_local_test(
    name = "environment",
    srcs = ["SampleTestWithEnvSetting.java"],
    data = ["env_location_data.txt"],
    env = {
        "android_local_test_test_env": "peekaboo",
        "android_local_test_loc_env": "$(location :env_location_data.txt)",
    },
    manifest = "AndroidManifest.xml",
    test_class = "com.starlark_resources.SampleTestWithEnvSetting",
    deps = [
        "@robolectric//bazel:android-all",
        "@maven//:androidx_test_core",
        "@maven//:androidx_test_ext_junit",
        "@maven//:junit_junit",
        "@maven//:org_hamcrest_hamcrest_core",
        "@maven//:org_robolectric_robolectric",
    ],
)

rule_test(
    name = "no_deps_with_resources_rule_test",
    target_under_test = ":no_deps_with_resources",
)

# TODO(b/161179595): Add test to exercise resource_configuration_filter wiring.

# TODO(aarmin): Add test to exercise densities and manifest_values wiring.

android_library(
    name = "resource_processing",
    assets = ["assets/bar.txt"],
    assets_dir = "assets",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
)

android_local_test(
    name = "single_resource_dep_without_manifest",
    srcs = ["SampleTest.java"],
    test_class = "com.starlark_resources.SampleTest",
    deps = [
        ":resource_processing",
        "@robolectric//bazel:android-all",
        "@maven//:androidx_test_core",
        "@maven//:androidx_test_ext_junit",
        "@maven//:junit_junit",
        "@maven//:org_robolectric_robolectric",
    ],
)

rule_test(
    name = "single_resource_dep_without_manifest_rule_test",
    target_under_test = ":single_resource_dep_without_manifest",
)

android_local_test(
    name = "single_resource_dep",
    srcs = ["SampleTest.java"],
    manifest = "AndroidManifest.xml",
    test_class = "com.starlark_resources.SampleTest",
    deps = [
        ":resource_processing",
        "@robolectric//bazel:android-all",
        "@maven//:androidx_test_core",
        "@maven//:androidx_test_ext_junit",
        "@maven//:junit_junit",
        "@maven//:org_robolectric_robolectric",
    ],
)

rule_test(
    name = "single_resource_dep_rule_test",
    target_under_test = ":single_resource_dep",
)

android_library(
    name = "resources_with_dep_with_res",
    assets = ["assets/foo.txt"],
    assets_dir = "assets",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["another_res/**"]),
    deps = [":resource_processing"],
)

android_local_test(
    name = "multiple_resource_deps",
    srcs = ["SampleTestMultipleDeps.java"],
    manifest = "AndroidManifest.xml",
    test_class = "com.starlark_resources.SampleTestMultipleDeps",
    deps = [
        ":resources_with_dep_with_res",
        "@robolectric//bazel:android-all",
        "@maven//:androidx_test_core",
        "@maven//:androidx_test_ext_junit",
        "@maven//:junit_junit",
        "@maven//:org_robolectric_robolectric",
    ],
)

rule_test(
    name = "multiple_resource_deps_rule_test",
    target_under_test = ":multiple_resource_deps",
)

android_library(
    name = "resource_processing_with_neverlink",
    manifest = "AndroidManifest.xml",
    neverlink = True,
    resource_files = glob(["res/**"]),
)

android_local_test(
    name = "depends_on_neverlink_lib",
    srcs = ["SampleTestNeverlinkDep.java"],
    custom_package = "com.starlark_resources.test",
    manifest = "AndroidManifest.xml",
    test_class = "com.starlark_resources.SampleTestNeverlinkDep",
    deps = [
        ":resource_processing_with_neverlink",
        "@robolectric//bazel:android-all",
        "@maven//:androidx_test_core",
        "@maven//:androidx_test_ext_junit",
        "@maven//:junit_junit",
        "@maven//:org_robolectric_robolectric",
    ],
)

android_local_test(
    name = "manifest_values_low_minsdk",
    srcs = ["SampleTest.java"],
    manifest = "AndroidManifest.xml",
    manifest_values = {"minSdkVersion": "15"},
    resource_files = glob(["res/**"]),
    test_class = "com.starlark_resources.SampleTest",
    deps = [
        "@robolectric//bazel:android-all",
        "@maven//:androidx_test_core",
        "@maven//:androidx_test_ext_junit",
        "@maven//:junit_junit",
        "@maven//:org_robolectric_robolectric",
    ],
)

android_local_test(
    name = "manifest_values_low_minsdk_no_manifest",
    srcs = ["SampleTest.java"],
    manifest_values = {"minSdkVersion": "15"},
    resource_files = glob(["res/**"]),
    test_class = "com.starlark_resources.SampleTest",
    deps = [
        "@robolectric//bazel:android-all",
        "@maven//:androidx_test_core",
        "@maven//:androidx_test_ext_junit",
        "@maven//:junit_junit",
        "@maven//:org_robolectric_robolectric",
    ],
)
