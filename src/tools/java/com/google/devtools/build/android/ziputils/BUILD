# Low level zip archive processing library.

load("@rules_java//java:defs.bzl", "java_binary", "java_library")

package(
    default_visibility = [
        "//src/test/java/com/google/devtools/build/android/ziputils:__pkg__",
        "//src/tools/java/com/google/devtools/build/android:__subpackages__",
        "//tools/android:__pkg__",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
)

java_library(
    name = "ziputils_lib",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_options_utils",
        "//tools/android:error_prone",
        "@rules_android_maven//:com_beust_jcommander",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
    ],
)

java_binary(
    name = "mapper",
    main_class = "com.google.devtools.build.android.ziputils.DexMapper",
    runtime_deps = [":ziputils_lib"],
)

java_binary(
    name = "reducer",
    main_class = "com.google.devtools.build.android.ziputils.DexReducer",
    runtime_deps = [":ziputils_lib"],
)
