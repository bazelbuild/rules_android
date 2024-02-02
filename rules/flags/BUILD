# Flags for Android rules and mobile-install

load("//rules/flags:additional_flags.bzl", "additional_flags")
load("//rules/flags:flag_defs.bzl", "define_flags")
load("//rules/flags:flags.bzl", "flags")
load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@bazel_skylib//rules:common_settings.bzl", "string_flag")

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
    visibility = ["//:__subpackages__"],
    deps = ["@bazel_skylib//rules:common_settings"],
)

string_flag(
    name = "runfiles_root_prefix",
    build_setting_default = "rules_android/",
    visibility = ["//visibility:public"],
)

define_flags()

additional_flags()

flags.FLAGS()
