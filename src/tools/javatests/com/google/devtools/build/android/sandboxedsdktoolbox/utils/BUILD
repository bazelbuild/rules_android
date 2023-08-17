# Common test utilities for SandboxedSdkToolbox.
package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "utils",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox:sandboxed_sdk_toolbox_lib",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
