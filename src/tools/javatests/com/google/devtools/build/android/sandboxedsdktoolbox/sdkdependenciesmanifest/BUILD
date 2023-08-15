# Tests for generate-sdk-dependencies-manifest command.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src:__subpackages__"],
)

licenses(["notice"])

java_test(
    name = "GenerateSdkDependenciesManifestCommandTest",
    size = "small",
    srcs = ["GenerateSdkDependenciesManifestCommandTest.java"],
    data = [
        "testdata/com.example.firstsdkconfig.json",
        "testdata/com.example.secondsdkconfig.json",
        "testdata/expected_manifest_multiple_sdks.xml",
        "testdata/expected_manifest_single_sdk.xml",
        "testdata/test_key",
    ],
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox:sandboxed_sdk_toolbox_lib",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:info_picocli_picocli",
        "@rules_android_maven//:junit_junit",
    ],
)
