# Flags for Android rules and mobile-install

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:common_settings.bzl", "bool_flag", "int_flag", "string_flag", "string_list_flag")
load("//rules/flags:additional_flags.bzl", "additional_flags")
load("//rules/flags:configurations.bzl", "configurations")
load("//rules/flags:flag_defs.bzl", "define_flags")
load("//rules/flags:flags.bzl", "flags")

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

filegroup(
    name = "empty",
    srcs = [],
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//:__subpackages__"],
    deps = [
        "//rules:visibility_bzl",
        "@bazel_skylib//rules:common_settings",
    ],
)

bool_flag(
    name = "desugar_for_android",
    build_setting_default = True,
    scope = "universal",
    visibility = ["//visibility:public"],
)

string_flag(
    name = "runfiles_root_prefix",
    build_setting_default = "rules_android/",
    visibility = ["//visibility:public"],
)

string_list_flag(
    name = "android_platforms",
    build_setting_default = [],
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "desugar_java8_libs",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "android_resource_shrinking",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "experimental_android_resource_path_shortening",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

string_flag(
    name = "android_manifest_merger_order",
    build_setting_default = "alphabetical",
    scope = "universal",
    values = [
        "alphabetical",
        "alphabetical_by_configuration",
        "dependency",
    ],
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "experimental_android_compress_java_resources",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "android_fixed_resource_neverlinking",
    build_setting_default = True,
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "experimental_persistent_aar_extractor",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "internal_persistent_busybox_tools",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "internal_persistent_multiplex_busybox_tools",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "internal_persistent_android_dex_desugar",
    build_setting_default = False,
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "internal_persistent_multiplex_android_dex_desugar",
    build_setting_default = False,
    visibility = ["//visibility:public"],
)

label_flag(
    name = "optimizing_dexer",
    build_setting_default = ":empty",
    visibility = ["//visibility:public"],
)

string_flag(
    name = "android_compiler",
    build_setting_default = "null",
    visibility = ["//visibility:public"],
)

string_list_flag(
    name = "dexopts_supported_in_dexmerger",
    build_setting_default = [
        "--minimal-main-dex",
        "--set-max-idx-number",
    ],
    scope = "universal",
    visibility = ["//visibility:public"],
)

string_list_flag(
    name = "dexopts_supported_in_dexsharder",
    build_setting_default = ["--minimal-main-dex"],
    scope = "universal",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "experimental_android_resource_shrinking",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "experimental_android_resource_cycle_shrinking",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

string_flag(
    name = "android_manifest_merger",
    build_setting_default = "android",
    scope = "universal",
    values = [
        "legacy",
        "android",
        "force_android",
    ],
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "experimental_android_library_exports_manifest_default",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

label_flag(
    name = "legacy_main_dex_list_generator",
    build_setting_default = ":empty",
    visibility = ["//visibility:public"],
)

bool_flag(
    name = "experimental_get_android_java_resources_from_optimized_jar",
    build_setting_default = False,
    scope = "universal",
    visibility = ["//visibility:public"],
)

int_flag(
    name = "incremental_dexing_after_proguard",
    build_setting_default = 50,
    scope = "universal",
    visibility = ["//visibility:public"],
)

configurations()

define_flags()

additional_flags()

flags.FLAGS()
