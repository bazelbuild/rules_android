# Description:
#   Defines the Android toolchain.

load("@bazel_skylib//:bzl_library.bzl", "bzl_library")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load(":toolchain.bzl", "android_toolchain")

licenses(["notice"])

filegroup(
    name = "all_files",
    srcs = glob(["**"]),
    visibility = ["//:__pkg__"],
)

# Android Toolchain Type
toolchain_type(
    name = "toolchain_type",
    visibility = ["//visibility:public"],
)

# Default Android Toolchain
android_toolchain(
    name = "android_default",
    visibility = ["//visibility:public"],
)

toolchain(
    name = "android_default_toolchain",
    toolchain = ":android_default",
    toolchain_type = ":toolchain_type",
)

bzl_library(
    name = "bzl",
    srcs = glob(["*.bzl"]),
)

genrule(
    name = "gen_unzip",
    outs = ["unzip.sh"],
    cmd = """cat > $@ <<EOF
unzip \\$$@
EOF
""",
    executable = True,
)

sh_binary(
    name = "zip",
    srcs = [":zip.sh"],
    visibility = ["//visibility:public"],
)

sh_binary(
    name = "unzip",
    srcs = [":unzip.sh"],
    visibility = ["//visibility:public"],
)
