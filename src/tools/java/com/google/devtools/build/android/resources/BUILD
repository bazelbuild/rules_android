# Description:
#   Tools for android resource processing

load("@rules_java//java:defs.bzl", "java_library")

package(default_visibility = [
    "//src/test/java/com/google/devtools/build/android:__subpackages__",
    "//src/tools/java/com/google/devtools/build/android:__pkg__",
])

java_library(
    name = "resources",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android:android_common_jar",
        "//src/tools/java/com/google/devtools/build/android:dependency_info",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:org_ow2_asm_asm",
        "@rules_android_maven//:org_ow2_asm_asm_commons",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = ["//src/tools/java/com/google/devtools/build/android:__pkg__"],
)
