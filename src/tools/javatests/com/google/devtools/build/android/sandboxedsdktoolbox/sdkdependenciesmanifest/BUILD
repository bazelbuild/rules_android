# Tests for generate-sdk-dependencies-manifest command.
load("@rules_java//java:defs.bzl", "java_test")

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
        "@maven//:com_android_tools_build_bundletool",
        "@maven//:com_google_protobuf_protobuf_java_util",
        "@maven//:com_google_truth_truth",
        "@maven//:junit_junit",
    ],
)
