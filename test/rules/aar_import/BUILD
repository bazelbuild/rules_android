load("@bazel_skylib//rules:build_test.bzl", "build_test")
load("@rules_java//java:java_library.bzl", "java_library")
load("//rules:rules.bzl", "aar_import")

java_library(
    name = "sample_classes",
    srcs = ["java/com/sample/Sample.java"],
)

genrule(
    name = "gen_sample_aar",
    srcs = [
        "AndroidManifest.xml",
        ":libsample_classes.jar",
    ],
    outs = ["sample.aar"],
    cmd = "$(location @bazel_tools//tools/zip:zipper) c $@ " +
          "AndroidManifest.xml=$(location AndroidManifest.xml) " +
          "classes.jar=$(location :libsample_classes.jar)",
    tools = ["@bazel_tools//tools/zip:zipper"],
)

aar_import(
    name = "sample_aar",
    aar = ":sample.aar",
)

# Checks that ImportDepsChecker validation passes for classes that use
# lambdas or string concatenation.
build_test(
    name = "sample_aar_import_build_test",
    targets = [":sample_aar"],
)
