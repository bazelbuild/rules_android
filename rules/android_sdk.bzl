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

load(
    "//providers:providers.bzl",
    "AndroidSdkInfo",
    "AndroidSdkTargetsInfo",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":attrs.bzl", "ANDROID_SDK_ATTRS")

visibility(PROJECT_VISIBILITY)

def _impl(ctx):
    proguard = ctx.attr._proguard if ctx.attr._proguard else ctx.attr.proguard
    android_sdk_info = AndroidSdkInfo(
        build_tools_version = ctx.attr.build_tools_version,
        framework_aidl = ctx.file.framework_aidl,
        aidl_lib = None,
        android_jar = ctx.file.android_jar,
        source_properties = ctx.file.source_properties,
        shrinked_android_jar = None,
        main_dex_classes = ctx.file.main_dex_classes,
        adb = ctx.attr.adb.files_to_run,
        dx = ctx.attr.dx.files_to_run,
        main_dex_list_creator = ctx.attr.main_dex_list_creator.files_to_run,
        aidl = ctx.attr.aidl.files_to_run,
        aapt = ctx.attr.aapt.files_to_run,
        aapt2 = ctx.attr.aapt2.files_to_run,
        apk_builder = ctx.attr.apkbuilder.files_to_run if ctx.attr.apkbuilder else None,
        apk_signer = ctx.attr.apksigner.files_to_run,
        proguard = proguard.files_to_run,
        zip_align = ctx.attr.zipalign.files_to_run,
        system = None,
        legacy_main_dex_list_generator = ctx.attr.legacy_main_dex_list_generator.files_to_run if ctx.attr.legacy_main_dex_list_generator else None,
    )
    android_sdk_targets_info = AndroidSdkTargetsInfo(
        build_tools_version = ctx.attr.build_tools_version,
        framework_aidl = ctx.attr.framework_aidl,
        android_jar = ctx.attr.android_jar,
        source_properties = ctx.attr.source_properties,
        main_dex_classes = ctx.attr.main_dex_classes,
        adb = ctx.attr.adb,
        dx = ctx.attr.dx,
        main_dex_list_creator = ctx.attr.main_dex_list_creator,
        aidl = ctx.attr.aidl,
        aapt = ctx.attr.aapt,
        aapt2 = ctx.attr.aapt2,
        apk_builder = ctx.attr.apkbuilder,
        apk_signer = ctx.attr.apksigner,
        proguard = proguard,
        zip_align = ctx.attr.zipalign,
        legacy_main_dex_list_generator = ctx.attr.legacy_main_dex_list_generator,
        core_for_system_modules_jar = ctx.attr.core_for_system_modules_jar,
        org_apache_http_legacy = ctx.attr.org_apache_http_legacy,
        sdk_path = ctx.attr.sdk_path,
        files = ctx.attr.files,
    )
    return [
        android_sdk_info,
        android_sdk_targets_info,
        platform_common.ToolchainInfo(
            android_sdk_info = android_sdk_info,
            android_sdk_targets_info = android_sdk_targets_info,
        ),
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
