# Command to generate the RuntimeEnabledSdkConfig file for app bundles.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "runtimeenabledsdkconfig",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/info",
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/mixin",
        "@rules_android_maven//:com_android_tools_build_bundletool",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
