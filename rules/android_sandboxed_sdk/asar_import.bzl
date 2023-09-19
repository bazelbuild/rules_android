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

"""Rule for importing an Android Sandboxed SDK archive for further processing."""

load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
load(
    "//rules:common.bzl",
    _common = "common",
)
load(
    "//rules:sandboxed_sdk_toolbox.bzl",
    _sandboxed_sdk_toolbox = "sandboxed_sdk_toolbox",
)
load(
    "//rules:utils.bzl",
    _get_android_toolchain = "get_android_toolchain",
)
load(":providers.bzl", "AndroidArchivedSandboxedSdkInfo")

def _impl(ctx):
    sdk_api_descriptors = ctx.actions.declare_file(ctx.label.name + "_sdk_api_descriptors.jar")
    _sandboxed_sdk_toolbox.extract_api_descriptors_from_asar(
        ctx,
        output = sdk_api_descriptors,
        asar = ctx.file.asar,
        sandboxed_sdk_toolbox = _get_android_toolchain(ctx).sandboxed_sdk_toolbox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )
    return [
        AndroidArchivedSandboxedSdkInfo(
            asar = ctx.file.asar,
            sdk_api_descriptors = sdk_api_descriptors,
        ),
    ]

asar_import = rule(
    attrs = _attrs.add(
        dict(
            asar = attr.label(
                allow_single_file = [".asar"],
            ),
        ),
        _attrs.JAVA_RUNTIME,
    ),
    executable = False,
    implementation = _impl,
    provides = [
        AndroidArchivedSandboxedSdkInfo,
    ],
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
    ],
)
