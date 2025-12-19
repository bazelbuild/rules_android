# Package for tool to check the contents of R classes

load("@rules_java//java:java_binary.bzl", "java_binary")

package(
    default_applicable_licenses = ["//:license"],
    default_visibility = ["//test:__subpackages__"],
)

java_binary(
    name = "RClassChecker",
    srcs = ["RClassChecker.java"],
    deps = [
        "@maven//:com_beust_jcommander",
        "@maven//:com_google_flogger_flogger",
        "@maven//:com_google_flogger_flogger_system_backend",
        "@maven//:com_google_guava_guava",
    ],
)
