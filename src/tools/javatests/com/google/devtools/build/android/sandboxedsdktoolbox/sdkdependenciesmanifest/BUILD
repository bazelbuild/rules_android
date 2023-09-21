# Tests for generate-sdk-dependencies-manifest command.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
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
        "//src/tools/javatests/com/google/devtools/build/android/sandboxedsdktoolbox/utils",
        "@rules_android_maven//:junit_junit",
        "@rules_android_maven//:com_google_truth_truth",
    ],
)
