load("@rules_java//java:defs.bzl", "java_library")

package(default_visibility = ["//visibility:private"])

package_group(
    name = "android-prod",
    packages = [
        "//src/tools/java/com/google/devtools/build/android",
    ],
)

package_group(
    name = "android-tests",
    packages = [
        "//src/test/java/com/google/devtools/build/android/...",
    ],
)

filegroup(
    name = "srcs",
    srcs = glob(["**"]),
    visibility = [":android-prod"],
)

filegroup(
    name = "embedded_tools",
    srcs = glob(["*.java"]),
    visibility = [":android-prod"],
)

genrule(
    name = "windows_file_jar_gen",
    srcs = ["@android_tools//:all_android_tools_deploy.jar"],
    outs = ["windows_file.jar"],
    cmd = "unzip -q $< 'com/google/devtools/build/lib/windows/*.class' && zip $@ $$(find . -name \"*.class\")",
)

java_import(
    name = "windows_file_jar",
    jars = [":windows_file_jar_gen"],
)

java_library(
    name = "junctions",
    srcs = glob(["*.java"]),
    visibility = [
        ":android-prod",
        ":android-tests",
    ],
    deps = [
        ":windows_file_jar",
        "@rules_android_maven//:com_google_code_findbugs_jsr305",
        "@rules_android_maven//:com_google_guava_guava",
    ],
)
