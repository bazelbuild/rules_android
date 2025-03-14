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
"""Common tools needed by the mobile-install aspect defined as aspect attributes."""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":dependency_map.bzl", "versioned_deps")

visibility(PROJECT_VISIBILITY)

TOOL_ATTRS = dict(
    # Target Attrs
    # This library should not be versioned. It needs to be built with the same
    # config that is used to build the app. Android binds the application to a
    # concrete architecture during install time. If no libs are on the apk, it
    # will select the most specific to the device is running. We want to use
    # whatever the user builds as long as it is compatible. And since we push
    # the native libs outside the apk to speed up transfer times, we need to
    # use dummy libs.
    _android_sdk = attr.label(
        default = Label(
            "//tools/android:android_jar",
        ),
        allow_files = True,
        cfg = "target",
    ),
    _flags = attr.label(
        default = Label(
            "//rules/flags",
        ),
    ),
    _studio_deployer = attr.label(
        default = Label("//tools/android:apkdeployer_deploy.jar"),
        allow_single_file = True,
        cfg = "exec",
        executable = True,
    ),
    _mi_java8_legacy_dex = attr.label(
        default = Label("//tools/android:java8_legacy_dex"),
        allow_single_file = True,
        cfg = "target",
    ),

    # Host Attrs
    _aapt2 = attr.label(
        default = Label(
            "@androidsdk//:aapt2_binary",
        ),
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _apk_signer = attr.label(
        default = Label("@apksig//:apksigner_deploy.jar"),
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _desugar_java8 = attr.label(
        default = Label("//tools/android:desugar_java8"),
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _desugared_lib_config = attr.label(
        allow_single_file = True,
        default = Label("//tools/android:full_desugar_jdk_libs_config_json"),
    ),
    _dexmerger = attr.label(
        cfg = "exec",
        default = Label("//tools/android:dexmerger"),
        executable = True,
    ),
    _dexbuilder = attr.label(
        cfg = "exec",
        default = Label("//tools/android:dexbuilder"),
        executable = True,
    ),
    _host_java_runtime = attr.label(
        default = Label("//tools/jdk:current_host_java_runtime"),
        cfg = "exec",
    ),
    _java_jdk = attr.label(
        default = Label("//tools/jdk:current_java_runtime"),
        allow_files = True,
        cfg = "exec",
    ),
    _java_toolchain = attr.label(
        default = Label("//tools/jdk:current_java_toolchain"),
    ),
    _resource_busybox = attr.label(
        default = Label("//src/tools/java/com/google/devtools/build/android:ResourceProcessorBusyBox_deploy.jar"),
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _zipalign = attr.label(
        default = Label(
            "@androidsdk//:zipalign_binary",
        ),
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),


    # Versioned Host Attrs
    _android_kit = attr.label(
        default = versioned_deps.android_kit.head,
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _deploy = attr.label(
        default = versioned_deps.deploy.head,
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _deploy_info = attr.label(
        default = versioned_deps.deploy_info.head,
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _jar_tool = attr.label(
        default = versioned_deps.jar_tool.head,
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _mi_android_java_toolchain = attr.label(
        default = Label("//tools/jdk:toolchain_android_only"),
    ),
    _mi_java_toolchain = attr.label(
        cfg = "exec",
        default = Label("//tools/jdk:toolchain"),
    ),
    _mi_host_javabase = attr.label(
        default = Label("//tools/jdk:current_host_java_runtime"),
    ),
    _res_v3_dummy_manifest = attr.label(
        allow_single_file = True,
        default = versioned_deps.res_v3_dummy_manifest.head,
    ),
    _res_v3_dummy_r_txt = attr.label(
        allow_single_file = True,
        default = versioned_deps.res_v3_dummy_r_txt.head,
    ),

)
