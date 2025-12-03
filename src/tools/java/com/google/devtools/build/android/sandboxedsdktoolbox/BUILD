# Common tools for managing sandboxed SDKs.
# Sandboxed SDKs are libraries that are released separately from Android apps and can run in the
# Privacy Sandbox.

load("@rules_java//java:defs.bzl", "java_binary", "java_library")
load("//tools/jdk:jvmopts.bzl", "BASE_JVMOPTS")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "sandboxed_sdk_toolbox_lib",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/apidescriptors",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/clientsources",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/proguardspecs",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/runtimeenabledsdkconfig",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/sdkdependenciesmanifest",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/sdksplitproperties",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/validatemodulesconfig",
        "@maven//:info_picocli_picocli",
    ],
)

java_binary(
    name = "sandboxed_sdk_toolbox",
    jvm_flags = BASE_JVMOPTS,
    main_class = "com.google.devtools.build.android.sandboxedsdktoolbox.SandboxedSdkToolbox",
    visibility = ["//visibility:public"],
    runtime_deps = [
        ":sandboxed_sdk_toolbox_lib",
    ],
)
