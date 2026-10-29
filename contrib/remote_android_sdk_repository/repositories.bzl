"""Utility functions to configure Android SDKs."""

load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//contrib/androidsdk_repository_alias:androidsdk_repository_alias.bzl", "androidsdk_repository_alias")
load(":remote_android_sdk_repository.bzl", "remote_android_sdk_repository")

def sdk_package(url, sha256, add_prefix = "", strip_prefix = ""):
    return dict(
        url = url,
        sha256 = sha256,
        add_prefix = add_prefix,
        strip_prefix = strip_prefix,
    )

def remote_android_sdk(
        name,
        api_level,
        build_tools_version,
        exec_compatible_with,
        build_tools,
        cmdline_tools,
        platforms,
        platform_tools,
        emulator,
        ndk):
    return dict(
        name = name,
        api_level = api_level,
        build_tools_version = build_tools_version,
        build_tools = build_tools,
        exec_compatible_with = exec_compatible_with,
        cmdline_tools = cmdline_tools,
        platforms = platforms,
        platform_tools = platform_tools,
        emulator = emulator,
        ndk = ndk,
    )

def register_android_sdks(sdks):
    for item in sdks:
        maybe(
            remote_android_sdk_repository,
            name = item["name"],
            sdk = item,
        )

    # Repo for backwards compatibility with usages of @androisdk
    androidsdk_repository_alias(name = "androidsdk")
