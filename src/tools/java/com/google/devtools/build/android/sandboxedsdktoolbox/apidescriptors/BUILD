# Command to extract API descriptors from a sandboxed SDK.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "apidescriptors",
    srcs = glob(["*.java"]),
    deps = [
        "@rules_android_maven//:androidx_privacysandbox_tools_tools_apipackager",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
