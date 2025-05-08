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
    name = "JunctionCreatorTest",
    size = "small",
    srcs = select({
        "@platforms//os:windows": ["WindowsJunctionCreatorTest.java"],
        "//conditions:default": ["NoopJunctionCreatorTest.java"],
    }),
    test_class = select({
        "@platforms//os:windows": "com.google.devtools.build.android.junctions.WindowsJunctionCreatorTest",
        "//conditions:default": "com.google.devtools.build.android.junctions.NoopJunctionCreatorTest",
    }),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/junctions",
        "@rules_android_maven//:com_google_truth_truth",
        "@rules_android_maven//:junit_junit",
    ],
)
