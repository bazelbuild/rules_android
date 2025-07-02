load("@rules_java//java:defs.bzl", "java_test")

package(
    default_testonly = 1,
    default_visibility = ["//src:__subpackages__"],
)

filegroup(
    name = "srcs",
    testonly = 0,
    srcs = glob(["**"]),
    visibility = ["//src/tools/javatests/com/google/devtools/build/android:__pkg__"],
)

java_test(
    name = "IdlClassTest",
    size = "small",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/idlclass:idlclass_lib",
        "@bazel_tools//src/main/protobuf:java_compilation_java_proto",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)
