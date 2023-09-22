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
    data = glob(["testdata/*"]),
    deps = [
        "//src/tools/javatests/com/google/devtools/build/android/sandboxedsdktoolbox/utils",
        "@rules_android_maven//:com_android_tools_build_bundletool",
        "@rules_android_maven//:com_google_protobuf_protobuf_java_util",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)
