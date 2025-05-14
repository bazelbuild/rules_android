# Description:
#   Collection of dex utilities used in the bazel android actions.

load("@rules_java//java:defs.bzl", "java_binary", "java_library")

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = [
        "//src/test/java/com/google/devtools/build/android/dexer:__pkg__",
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
    ],
)

java_binary(
    name = "DexFileSplitter",
    srcs = [
        "AsyncZipOut.java",
        "DexFileSplitter.java",
        "DexLimitTracker.java",
        "ZipEntryComparator.java",
        "ZipEntryPredicates.java",
    ],
    visibility = ["//visibility:public"],
    # Do not sort: Deps order matters until android_tools.jar deps are deleted (b/393172052).
    deps = [
        "@com_android_dex//:dex",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_errorprone_error_prone_annotations",
        "@rules_android_maven//:com_google_guava_guava",
        ":DexFileSplitter_lib",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
        "//tools/android:autovalue",
    ],
)

java_library(
    name = "DexFileSplitter_lib",
    srcs = [
        "AsyncZipOut.java",
        "DexFileSplitter.java",
        "DexLimitTracker.java",
        "ZipEntryComparator.java",
        "ZipEntryPredicates.java",
    ],
    visibility = ["//src/test/java/com/google/devtools/build/android/dexer:__pkg__"],
    # Do not sort: Deps order matters until android_tools.jar deps are deleted (b/393172052).
    deps = [
        "@bazel_worker_api//:worker_protocol_proto",
        "@com_android_dex//:dex",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_auto_value_auto_value",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_errorprone_error_prone_annotations",
        "@rules_android_maven//:com_google_guava_guava",
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
        "//tools/android:autovalue",
    ],
)

# The DexFileMerger and DexBuilder are built in BUILD.tools which is built in
# a developers workspace, not the Bazel workspace. So we must bundle the
# dependencies of those binaries into the embedded tools.
java_library(
    name = "dexerdeps",
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
    ],
    runtime_deps = [
        "//src/tools/java/com/google/devtools/build/android:android_builder_lib",
        "@bazel_worker_api//:worker_protocol_proto",
        "@rules_android_maven//:com_google_auto_value_auto_value",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
    ],
)
