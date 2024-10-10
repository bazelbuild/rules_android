# Description:
#   Tools for scanning bytecode for references to other classes and emitting Proguard-style keeps.

load("@rules_java//java:defs.bzl", "java_binary", "java_library")

filegroup(
    name = "embedded_tools",
    srcs = ["BUILD.tools"],
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
    ],
)

java_library(
    name = "scan",
    srcs = glob(["*.java"]),
    tags = ["manual"],
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
    ],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
        "//src/tools/java/com/google/devtools/build/android/desugar/io",
        "@rules_android_maven//:asm_asm",
        "@rules_android_maven//:asm_asm_commons",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_auto_value_auto_value",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
    ],
)

java_binary(
    name = "KeepScanner",
    testonly = 1,  # normally used through @bazel_tools
    main_class = "com.google.devtools.build.android.desugar.scan.KeepScanner",
    tags = ["manual"],
    visibility = [
        "//src/test/java/com/google/devtools/build/android/desugar/scan:__pkg__",
    ],
    runtime_deps = [":scan"],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = ["//src/tools/java/com/google/devtools/build/android/desugar:__pkg__"],
)
