# Command to validate SDK modules config.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "validatemodulesconfig",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/info",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
