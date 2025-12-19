# Command to generate the SdkSplitProperties file for sandboxed SDK dependencies.
load("@rules_java//java:defs.bzl", "java_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "sdksplitproperties",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/info",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/mixin",
        "@maven//:com_android_tools_build_bundletool",
        "@maven//:com_google_guava_guava",
        "@maven//:com_google_protobuf_protobuf_java",
        "@maven//:com_google_protobuf_protobuf_java_util",
        "@maven//:info_picocli_picocli",
    ],
)
