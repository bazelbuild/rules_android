load("@rules_java//java:defs.bzl", "java_binary", "java_library")

package(
    default_applicable_licenses = ["//:license"],
)

java_binary(
    name = "IdlClass",
    main_class = "com.google.devtools.build.android.idlclass.IdlClass",
    tags = ["manual"],
    visibility = ["//visibility:public"],
    runtime_deps = [":idlclass_lib"],
)

java_library(
    name = "idlclass_lib",
    srcs = glob(["*.java"]),
    tags = ["manual"],
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
        "//src/tools/javatests/com/google/devtools/build/android/idlclass:__pkg__",
    ],
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
        "//third_party/bazel/src/main/protobuf:java_compilation_java_proto",
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
