load("@rules_java//java:defs.bzl", "java_binary", "java_import", "java_library")
load("//tools/android:defs.bzl", "run_singlejar")

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

# NOTE: jarhelper actually exists in @bazel_tools, but its visibility is set too restrictively.
run_singlejar(
    name = "jarhelper_jar_gen",
    srcs = ["@android_tools//:all_android_tools_deploy.jar"],
    out = "jarhelper.jar",
    include_prefixes = [
        "com/google/devtools/build/buildjar/jarhelper/",
    ],
)

java_import(
    name = "jarhelper_jar",
    jars = [":jarhelper.jar"],
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
        ":jarhelper_jar",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
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
