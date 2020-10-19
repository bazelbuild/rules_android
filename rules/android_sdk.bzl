# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Bazel rule for Android sdk."""

load(":attrs.bzl", "ANDROID_SDK_ATTRS")

def _impl(ctx):
    proguard = ctx.attr._proguard if ctx.attr._proguard else ctx.attr.proguard
    android_sdk_info = AndroidSdkInfo(
        ctx.attr.build_tools_version,
        ctx.file.framework_aidl,
        ctx.attr.aidl_lib,
        ctx.file.android_jar,
        ctx.file.source_properties,
        ctx.file.shrinked_android_jar,
        ctx.file.main_dex_classes,
        ctx.attr.adb.files_to_run,
        ctx.attr.dx.files_to_run,
        ctx.attr.main_dex_list_creator.files_to_run,
        ctx.attr.aidl.files_to_run,
        ctx.attr.aapt.files_to_run,
        ctx.attr.aapt2.files_to_run,
        ctx.attr.apkbuilder.files_to_run if ctx.attr.apkbuilder else None,
        ctx.attr.apksigner.files_to_run,
        proguard.files_to_run,
        ctx.attr.zipalign.files_to_run,
        # Passing the 'system' here is only necessary to support native android_binary.
        # TODO(b/149114743): remove this after the migration to android_application.
        ctx.attr._system[java_common.BootClassPathInfo] if ctx.attr._system and java_common.BootClassPathInfo in ctx.attr._system else None,
    )
    return [
        android_sdk_info,
        platform_common.ToolchainInfo(android_sdk_info = android_sdk_info),
    ]

android_sdk = rule(
    attrs = ANDROID_SDK_ATTRS,
    implementation = _impl,
    fragments = ["java"],
    provides = [AndroidSdkInfo],
)
