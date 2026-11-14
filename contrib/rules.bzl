"""Starlark rules from external contributors for building Android apps."""

load(
    "//contrib/remote_android_sdk_repository:repositories.bzl",
    _register_android_sdks = "register_android_sdks",
    _remote_android_sdk = "remote_android_sdk",
    _sdk_package = "sdk_package",
)

register_android_sdks = _register_android_sdks
remote_android_sdk = _remote_android_sdk
sdk_package = _sdk_package
