load("@bazel_skylib//:bzl_library.bzl", "bzl_library")

exports_files([
    "data_binding_annotation_template.txt",
    "res_v3_dummy_AndroidManifest.xml",
    "res_v3_dummy_R.txt",
    "robolectric_properties_template.txt",
])

alias(
    name = "ResourceProcessorBusyBox",
    actual = "@bazel_tools//tools/android:busybox",
    visibility = ["//visibility:public"],
)

bzl_library(
    name = "android_revision_bzl",
    srcs = [
        "android_revision.bzl",
    ],
    visibility = ["//:__subpackages__"],
)

bzl_library(
    name = "common_bzl",
    srcs = [
        "aapt.bzl",
        "acls.bzl",
        "attrs.bzl",
        "bundletool.bzl",
        "busybox.bzl",
        "common.bzl",
        "data_binding.bzl",
        "idl.bzl",
        "intellij.bzl",
        "java.bzl",
        "migration_tag_DONOTUSE.bzl",
        "native_deps.bzl",
        "native_toolchain_attrs.bzl",
        "path.bzl",
        "processing_pipeline.bzl",
        "proguard.bzl",
        "providers.bzl",
        "resources.bzl",
        "utils.bzl",
    ],
    visibility = ["//:__subpackages__"],
    deps = [
        "//rules/acls:bzl",
        "//rules/android_common:bzl",
        "//rules/flags:bzl",
    ],
)
