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
    name = "RClassGeneratorTest",
    size = "small",
    srcs = glob([
        "**/*.java",
    ]),
    runtime_deps = [
        "@maven//:com_google_guava_guava",
    ],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_common_30_1_3",
        "//src/tools/java/com/google/devtools/build/android/resources",
        "@maven//:com_google_guava_failureaccess",
        "@maven//:com_google_guava_guava",
        "@maven//:com_google_truth_truth",
        "@maven//:junit_junit",
    ],
)
