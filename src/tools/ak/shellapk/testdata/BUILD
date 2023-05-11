# Creates test data for testing the shellapk action.

load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

package(default_visibility = ["//src/tools/ak/shellapk:__subpackages__"])

licenses(["notice"])

genrule(
    name = "app_name",
    outs = ["app_name.txt"],
    cmd = "printf 'com.example.ExampleApplication' > '$@'",
)

genrule(
    name = "manifest_package_name",
    outs = ["manifest_package_name.txt"],
    cmd = "printf 'com.example' > '$@'",
)

genrule(
    name = "android_manifest",
    srcs = ["//src/java/com/example/sampleapp:sampleapp.apk"],
    outs = ["AndroidManifest.xml"],
    cmd = "unzip -p $(location //src/java/com/example/sampleapp:sampleapp.apk) AndroidManifest.xml > '$@'",
)

genrule(
    name = "res",
    srcs = ["//src/java/com/example/sampleapp:sampleapp.apk"],
    outs = ["res.zip"],
    cmd = """
unzip $(location //src/java/com/example/sampleapp:sampleapp.apk) res/*
zip -r $@ res
rm -r res/
""",
)

genrule(
    name = "dexes",
    srcs = ["//src/java/com/example/sampleapp:sampleapp.apk"],
    outs = ["dexes.zip"],
    cmd = """
mkdir $(@D)/tmp
unzip -p $(location //src/java/com/example/sampleapp:sampleapp.apk) classes.dex > $(@D)/tmp/classes.dex
zip -j $@ $(@D)/tmp/classes.dex
rm -r $(@D)/tmp
""",
)

genrule(
    name = "native_lib",
    srcs = ["//src/java/com/example/sampleapp:sampleapp.apk"],
    outs = ["native_lib.zip"],
    cmd = """
unzip $(location //src/java/com/example/sampleapp:sampleapp.apk) lib/*
zip -r $@ lib
rm -r lib/
""",
)
