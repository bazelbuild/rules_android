# Description:
#   Tests for the Java 8 desugaring tool for Android.
package(
    default_testonly = 1,
    default_visibility = ["//src/tools/javatests/com/google/devtools/build/android/desugar:__subpackages__"],
)

licenses(["notice"])  # Apache 2.0

filegroup(
    name = "srcs",
    testonly = 0,
    srcs = glob(["**"]) + [
        "//src/tools/javatests/com/google/devtools/build/android/desugar/dependencies:srcs",
    ],
    visibility = ["//src/tools/javatests/com/google/devtools/build/android:__pkg__"],
)
