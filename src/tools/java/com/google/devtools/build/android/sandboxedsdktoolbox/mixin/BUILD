# Package for mixins with shared logic between commands.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//src:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "mixin",
    srcs = glob(["*.java"]),
    deps = [
        "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox/info",
        "@rules_android_maven//:com_google_guava_guava",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
