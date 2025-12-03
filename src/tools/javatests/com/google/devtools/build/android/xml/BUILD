load("@rules_java//java:defs.bzl", "java_test")

filegroup(
    name = "srcs",
    testonly = 0,
    srcs = glob(["**"]),
    visibility = ["//src/tools/javatests/com/google/devtools/build/android:__pkg__"],
)

java_test(
    name = "IdXmlResourceValueTest",
    size = "small",
    srcs = ["IdXmlResourceValueTest.java"],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android/proto:resources_java_proto",
        "//src/tools/java/com/google/devtools/build/android/resources",
        "@maven//:com_google_errorprone_error_prone_annotations",
        "@maven//:com_google_truth_truth",
        "@maven//:junit_junit",
    ],
)

java_test(
    name = "ProtoXmlUtilsTest",
    size = "small",
    srcs = ["ProtoXmlUtilsTest.java"],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android/proto:resources_java_proto",
        "@maven//:com_google_truth_truth",
        "@maven//:junit_junit",
    ],
    runtime_deps = [
        "@maven//:com_google_guava_guava",
    ],
)

java_test(
    name = "SimpleXmlResourceValueTest",
    size = "small",
    srcs = ["SimpleXmlResourceValueTest.java"],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android/proto:resources_java_proto",
        "@maven//:com_google_truth_truth",
        "@maven//:junit_junit",
    ],
)
