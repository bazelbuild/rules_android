# Tests for generate-runtime-enabled-sdk-config command.
load("@rules_java//java:defs.bzl", "java_test")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_test(
    name = "GenerateRuntimeEnabledSdkConfigCommandTest",
    size = "small",
    srcs = ["GenerateRuntimeEnabledSdkConfigCommandTest.java"],
    data = glob(["testdata/*"]),
    deps = [
        "//src/tools/javatests/com/google/devtools/build/android/sandboxedsdktoolbox/utils",
        "@maven//:com_android_tools_build_bundletool",
        "@maven//:com_google_guava_guava",
        "@maven//:com_google_protobuf_protobuf_java",
        "@maven//:com_google_truth_truth",
        "@maven//:junit_junit",
    ],
)

java_test(
    name = "GenerateRuntimeEnabledSdkTableCommandTest",
    size = "small",
    srcs = ["GenerateRuntimeEnabledSdkTableCommandTest.java"],
    deps = [
        "//src/tools/javatests/com/google/devtools/build/android/sandboxedsdktoolbox/utils",
        "@maven//:com_android_tools_build_bundletool",
        "@maven//:com_google_guava_guava",
        "@maven//:com_google_protobuf_protobuf_java_util",
        "@maven//:com_google_truth_truth",
        "@maven//:junit_junit",
    ],
)
