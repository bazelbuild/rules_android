# Description:
#   Collection of dex utilities used in the bazel android actions.

load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load("//rules:min_sdk_version.bzl", "min_sdk_version")

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
        "//src/tools/javatests/com/google/devtools/build/android/r8:__pkg__",
    ],
)

java_library(
    name = "r8",
    srcs = glob(
        [
            "*.java",
            "desugar/*.java",
        ],
        exclude = [
            "NoAndroidSdkStub.java",
        ],
    ),
    visibility = [
        "//visibility:public",
    ],
    runtime_deps = [
        "//src/tools/java/com/google/devtools/build/android/desugar/dependencies",
    ],
    deps = [
        ":constants",
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
        "//tools/android:autovalue",
        "@bazel_worker_java//src/main/java/com/google/devtools/build/lib/worker:work_request_handlers",
        "@maven//:com_android_tools_r8",
        "@maven//:com_beust_jcommander",
        "@maven//:com_google_code_findbugs_jsr305",
        "@maven//:com_google_guava_guava",
        "@maven//:org_ow2_asm_asm",
        "@maven//:org_ow2_asm_asm_commons",
    ],
)

java_library(
    name = "utils",
    srcs = ["R8Utils.java"],
)

java_library(
    name = "deps_collector_api",
    srcs = ["DependencyCollector.java"],
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__subpackages__",
        "//src/tools/java/com/google/devtools/build/android/r8:__subpackages__",
        "//src/tools/javatests/com/google/devtools/build/android/desugar:__subpackages__",
    ],
    deps = [
        ":utils",
        "@maven//:com_google_code_findbugs_jsr305",
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
        # CompatDexBuilder depends on some worker utilities.
        "@bazel_worker_java//src/main/java/com/google/devtools/build/lib/worker:work_request_handlers",
    ],
)

java_binary(
    name = "desugar",
    jvm_flags = [
        # b/71513487
        "-XX:+TieredCompilation",
        "-XX:TieredStopAtLevel=1",
        "-Xms8g",
        "-Xmx8g",
    ],
    main_class = "com.google.devtools.build.android.r8.Desugar",
    visibility = [
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
        "//src/tools/javatests/com/google/devtools/build/android/r8:__subpackages__",
        "//tools/android:__pkg__",
    ],
    runtime_deps = [
        ":r8",
    ],
)

java_binary(
    name = "core_library_desugar",
    jvm_flags = [
        # b/71513487
        "-XX:+TieredCompilation",
        "-XX:TieredStopAtLevel=1",
        # b/172508621
        "-Dcom.android.tools.r8.sortMethodsOnCfWriting",
        "-Dcom.android.tools.r8.disableL8AnnotationRemoval",
    ],
    main_class = "com.google.devtools.build.android.r8.CoreLibraryDesugar",
    visibility = [
        "//visibility:public",
    ],
    runtime_deps = [
        ":r8",
    ],
)

java_binary(
    name = "dexbuilder",
    main_class = "com.google.devtools.build.android.r8.CompatDexBuilder",
    visibility = [
        "//src/tools/javatests/com/google/devtools/build/android/dexer:__pkg__",
    ],
    runtime_deps = [
        ":r8",
    ],
)

java_library(
    name = "constants",
    srcs = [":Constants_java"],
    visibility = [
        ":__pkg__",
        "//src/tools/java/com/google/devtools/build/android:__pkg__",
    ],
)

genrule(
    name = "Constants_java",
    outs = ["Constants.java"],
    cmd = """
cat > $@ << EOF
package com.google.devtools.build.android.r8;
/** Constants shared by desugaring and dexing. */
public class Constants {
  public static final String MIN_API_LEVEL = "%s";
  private Constants() {}
}
EOF
""" % str(min_sdk_version.DEPOT_FLOOR),
    visibility = [":__pkg__"],
)
