# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Rule for creating an Android Sandboxed SDK Bundle (ASB)."""

load(":providers.bzl", "AndroidSandboxedSdkBundleInfo", "AndroidSandboxedSdkInfo")
load(
    "//rules:aapt.bzl",
    _aapt = "aapt",
)
load(
    "//rules:bundletool.bzl",
    _bundletool = "bundletool",
)
load(
    "//rules:common.bzl",
    _common = "common",
)
load(
    "//rules:utils.bzl",
    _get_android_toolchain = "get_android_toolchain",
)

_ATTRS = dict(
    sdk = attr.label(
        providers = [
            [AndroidSandboxedSdkInfo],
        ],
    ),
    _host_javabase = attr.label(
        cfg = "exec",
        default = Label("//tools/jdk:current_java_runtime"),
    ),
)

def _impl(ctx):
    host_javabase = _common.get_host_javabase(ctx)

    # Convert internal APK to proto resources.
    internal_proto_apk = ctx.actions.declare_file(ctx.label.name + "_internal_proto_apk")
    _aapt.convert(
        ctx,
        out = internal_proto_apk,
        input = ctx.attr.sdk[AndroidSandboxedSdkInfo].internal_apk_info.unsigned_apk,
        to_proto = True,
        aapt = _get_android_toolchain(ctx).aapt2.files_to_run,
    )

    # Invoke module builder to create a base.zip that bundletool accepts.
    module_zip = ctx.actions.declare_file(ctx.label.name + "_module.zip")
    _bundletool.build_sdk_module(
        ctx,
        out = module_zip,
        internal_apk = internal_proto_apk,
        bundletool_module_builder =
            _get_android_toolchain(ctx).bundletool_module_builder.files_to_run,
        host_javabase = host_javabase,
    )

    # Invoke bundletool and create the bundle.
    _bundletool.build_sdk_bundle(
        ctx,
        out = ctx.outputs.asb,
        module = module_zip,
        sdk_modules_config = ctx.attr.sdk[AndroidSandboxedSdkInfo].sdk_module_config,
        bundletool = _get_android_toolchain(ctx).bundletool.files_to_run,
        host_javabase = host_javabase,
    )

    return [
        AndroidSandboxedSdkBundleInfo(
            asb = ctx.outputs.asb,
            sdk_info = ctx.attr.sdk[AndroidSandboxedSdkInfo],
        ),
    ]

android_sandboxed_sdk_bundle = rule(
    attrs = _ATTRS,
    executable = False,
    implementation = _impl,
    provides = [
        AndroidSandboxedSdkBundleInfo,
    ],
    outputs = {
        "asb": "%{name}.asb",
    },
    toolchains = [
        "//toolchains/android:toolchain_type",
        "//toolchains/android_sdk:toolchain_type",
    ],
    fragments = ["android"],
)
