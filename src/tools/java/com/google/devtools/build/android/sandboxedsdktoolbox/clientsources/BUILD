# Command to generate sources for communicating with a sandboxed SDK.

load("@rules_java//java:defs.bzl", "java_library")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

java_library(
    name = "clientsources",
    srcs = glob(["*.java"]),
    deps = [
        "@maven//:androidx_privacysandbox_tools_tools_apigenerator",
        "@maven//:info_picocli_picocli",
    ],
)
