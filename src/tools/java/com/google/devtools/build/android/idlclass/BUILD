load("@rules_java//java:defs.bzl", "java_binary", "java_library")

filegroup(
    name = "embedded_tools",
    srcs = ["BUILD.tools"],
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
    ],
)

java_binary(
    name = "IdlClass",
    main_class = "com.google.devtools.build.android.idlclass.IdlClass",
    tags = ["manual"],
    runtime_deps = [":idlclass_lib"],
)

java_library(
    name = "idlclass_lib",
    srcs = glob(["*.java"]),
    tags = ["manual"],
    visibility = [
        "//src/test/java/com/google/devtools/build/android/idlclass:__pkg__",
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
    ],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
        "@bazel_tools//src/java_tools/buildjar/java/com/google/devtools/build/buildjar/jarhelper",
        "@bazel_tools//src/main/protobuf:java_compilation_java_proto",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
    ],
)
