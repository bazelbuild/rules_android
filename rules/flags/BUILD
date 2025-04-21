# Flags for Android rules and mobile-install

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:common_settings.bzl", "string_flag")
load("//rules/flags:additional_flags.bzl", "additional_flags")
load("//rules/flags:configurations.bzl", "configurations")
load("//rules/flags:flag_defs.bzl", "define_flags")
load("//rules/flags:flags.bzl", "flags")

licenses(["notice"])

package(
    default_applicable_licenses = ["//:license"],
)

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//rules:__pkg__"]
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

string_flag(
    name = "runfiles_root_prefix",
    build_setting_default = "rules_android/",
    visibility = ["//visibility:public"],
)

configurations()

define_flags()

additional_flags()

flags.FLAGS()
