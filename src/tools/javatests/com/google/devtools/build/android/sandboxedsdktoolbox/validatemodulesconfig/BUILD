# Tests for validate-modules-config command.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_test(
    name = "ValidateModulesConfigCommandTest",
    size = "small",
    srcs = ["ValidateModulesConfigCommandTest.java"],
    data = glob(["testdata/*"]),
    deps = [
        "//src/tools/javatests/com/google/devtools/build/android/sandboxedsdktoolbox/utils",
        "@rules_android_maven//:com_android_tools_build_bundletool",
        "@rules_android_maven//:com_google_protobuf_protobuf_java_util",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)
