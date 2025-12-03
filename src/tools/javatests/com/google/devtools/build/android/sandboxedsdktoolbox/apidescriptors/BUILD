# Tests for extract-api-descriptors command.
load("@rules_java//java:defs.bzl", "java_test")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src:__subpackages__"],
)

licenses(["notice"])

java_test(
    name = "ExtractApiDescriptorsCommandTest",
    size = "small",
    srcs = ["ExtractApiDescriptorsCommandTest.java"],
    data = [
        "//src/tools/javatests/com/google/devtools/build/android/sandboxedsdktoolbox/apidescriptors/testlibrary:libtestlibrary.jar",
    ],
    deps = [
        "//src/tools/javatests/com/google/devtools/build/android/sandboxedsdktoolbox/utils",
        "@maven//:com_google_guava_guava",
        "@maven//:com_google_truth_truth",
        "@maven//:junit_junit",
    ],
)
