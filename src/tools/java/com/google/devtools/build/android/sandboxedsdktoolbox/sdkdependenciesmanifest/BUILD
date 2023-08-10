# Command for generating an SDK dependencies Android manifest.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "sdkdependenciesmanifest",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/config",
        "@rules_android_maven//:com_android_tools_build_bundletool",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
