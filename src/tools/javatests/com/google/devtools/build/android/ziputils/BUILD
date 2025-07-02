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
    name = "ziputils-tests",
    size = "small",
    srcs = glob(["*.java"]),
    tags = ["ziputils"],
    test_class = "com.google.devtools.build.android.ziputils.AllTests",
    deps = [
        "//src/tools/java/com/google/devtools/build/android/ziputils:ziputils_lib",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)
