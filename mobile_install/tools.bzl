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
"""Tools needed by the mobile-install aspect defined as aspect attributes."""

load(":dependency_map.bzl", "versioned_deps")

TOOL_ATTRS = dict(
    # Target Attrs
    # This library should not be versioned. It needs to be built with the same
    # config that is used to build the app. Android binds the application to a
    # concrete achitecture during install time. If no libs are on the apk, it
    # will select the most specific to the device is running. We want to use
    # whatever the user builds as long as it is compatible. And since we push
    # the native libs outside the apk to speed up transfer times, we need to
    # use dummy libs.
    _android_sdk = attr.label(
        default = Label(
            "@androidsdk//:sdk",
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
        default = "@androidsdk//:fail", # TODO(#119): Studio deployer jar to be released
        allow_single_file = True,
        cfg = "exec",
        executable = True,
    ),
    _mi_shell_dummy_native_libs = attr.label(
        default = Label(
            "@androidsdk//:fail", # FIXME: Unused internally
        ),
        allow_single_file = True,
        cfg = "target",
    ),
    _mi_shell_app = attr.label(
        default = versioned_deps.mi_shell_app.head,
        allow_files = True,
        cfg = "target",
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
        allow_single_file = True,
        cfg = "exec",
        executable = True,
    ),
    _android_test_runner = attr.label(
        default = Label(
            "@bazel_tools//tools/jdk:TestRunner_deploy.jar",
        ),
        allow_single_file = True,
        cfg = "exec",
        executable = True,
    ),
    _apk_signer = attr.label(
        default = Label("@androidsdk//:apksigner"),
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
    _d8 = attr.label(
        default = Label("@bazel_tools//src/tools/android/java/com/google/devtools/build/android/r8:r8"),
        allow_files = True,
        cfg = "exec",
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
    _resource_busybox = attr.label(
        default = Label("@bazel_tools//src/tools/android/java/com/google/devtools/build/android:ResourceProcessorBusyBox_deploy.jar"),
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _zipalign = attr.label(
        default = Label(
            "@androidsdk//:zipalign_binary",
        ),
        allow_single_file = True,
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
    _make_sync = attr.label(
        default = versioned_deps.make_sync.head,
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _merge_syncs = attr.label(
        default = versioned_deps.merge_syncs.head,
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
    _pack_dexes = attr.label(
        default = versioned_deps.pack_dexes.head,
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _pack_generic = attr.label(
        default = versioned_deps.pack_generic.head,
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),
    _res_v3_dummy_manifest = attr.label(
        allow_single_file = True,
        default = versioned_deps.res_v3_dummy_manifest.head,
    ),
    _res_v3_dummy_r_txt = attr.label(
        allow_single_file = True,
        default = versioned_deps.res_v3_dummy_r_txt.head,
    ),
    _resource_extractor = attr.label(
        allow_single_file = True,
        cfg = "exec",
        default = versioned_deps.resource_extractor.head,
        executable = True,
    ),
    _sync_merger = attr.label(
        default = versioned_deps.sync_merger.head,
        allow_files = True,
        cfg = "exec",
        executable = True,
    ),

)
