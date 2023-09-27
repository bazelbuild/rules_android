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
        "android_neverlink_aspect.bzl",
        "attrs.bzl",
        "bundletool.bzl",
        "busybox.bzl",
        "common.bzl",
        "data_binding.bzl",
        "idl.bzl",
        "instrumented_app_info_aspect.bzl",
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
        "sandboxed_sdk_toolbox.bzl",
        "utils.bzl",
    ],
    visibility = ["//:__subpackages__"],
    deps = [
        "//rules/acls:bzl",
        "//rules/android_common:bzl",
        "//rules/flags:bzl",
    ],
)

bzl_library(
    name = "android_binary_bzl",
    srcs = [
        "android_binary.bzl",
    ],
    visibility = ["//:__subpackages__"],
    deps = [
        "//rules/android_binary_internal:bzl",
    ],
)

bzl_library(
    name = "bzl",
    srcs = [
        "android_ndk_repository.bzl",
        "android_sdk.bzl",
        "android_tools_defaults_jar.bzl",
        "baseline_profiles.bzl",
        "dex.bzl",
        "dex_desugar_aspect.bzl",
        "rules.bzl",
    ],
    visibility = ["//mobile_install:__pkg__"],
    deps = [
        ":android_binary_bzl",
        ":common_bzl",
        "//rules/aar_import:bzl",
        "//rules/android_library:bzl",
        "//rules/android_sandboxed_sdk:bzl",
        "//rules/android_sdk_repository:bzl",
        "//rules/flags:bzl",
    ],
)
