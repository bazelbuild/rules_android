# Command to generate sources for communicating with a sandboxed SDK.

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "clientsources",
    srcs = glob(["*.java"]),
    deps = [
        "@rules_android_maven//:androidx_privacysandbox_tools_tools_apigenerator",
        "@rules_android_maven//:info_picocli_picocli",
    ],
)
