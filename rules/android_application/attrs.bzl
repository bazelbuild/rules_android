# Copyright 2021 The Bazel Authors. All rights reserved.
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
"""Attributes for android_application."""

load(
    "//providers:providers.bzl",
    "AndroidArchivedSandboxedSdkInfo",
    "AndroidSandboxedSdkBundleInfo",
)
load("//rules:android_split_transition.bzl", "android_split_transition")
load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":android_feature_module_validation_aspect.bzl", "android_feature_module_validation_aspect")

visibility(PROJECT_VISIBILITY)

ANDROID_APPLICATION_ATTRS = _attrs.add(
    dict(
        manifest_values = attr.string_dict(),
        base_module = attr.label(allow_files = False),
        bundle_config_file = attr.label(
            allow_single_file = [".pb.json"],
            doc = ("Path to config.pb.json file, see " +
                   "https://github.com/google/bundletool/blob/master/src/main/proto/config.proto " +
                   "for definition.\n\nNote: this attribute is subject to changes which may " +
                   "require teams to migrate their configurations to a build target."),
        ),
        app_integrity_config = attr.label(
            allow_single_file = [".binarypb"],
            doc = "Configuration of the integrity protection options. " +
                  "Provide a path to a binary .binarypb instance of " +
                  "https://github.com/google/bundletool/blob/master/src/main/proto/app_integrity_config.proto",
        ),
        rotation_config = attr.label(
            allow_single_file = [".textproto"],
            default = None,
        ),
        custom_package = attr.string(),
        feature_modules = attr.label_list(allow_files = False),
        sdk_archives = attr.label_list(
            providers = [
                [AndroidArchivedSandboxedSdkInfo],
            ],
        ),
        sdk_bundles = attr.label_list(
            providers = [
                [AndroidSandboxedSdkBundleInfo],
            ],
        ),
        _bundle_deploy = attr.label(
            allow_single_file = True,
            default = ":bundle_deploy.sh_template",
        ),
        _bundle_keystore_properties = attr.label(
            allow_single_file = True,
            default = None,
        ),
        _feature_manifest_script = attr.label(
            allow_single_file = True,
            cfg = "exec",
            executable = True,
            default = ":gen_android_feature_manifest.sh",
        ),
        _java_toolchain = attr.label(
            default = Label("//tools/jdk:toolchain_android_only"),
        ),
        _merge_manifests = attr.label(
            default = ":merge_feature_manifests",
            cfg = "exec",
            executable = True,
        ),
        _priority_feature_manifest_script = attr.label(
            allow_single_file = True,
            cfg = "exec",
            executable = True,
            default = ":gen_priority_android_feature_manifest.sh",
        ),
        _host_javabase = attr.label(
            cfg = "exec",
            default = Label("//tools/jdk:current_java_runtime"),
        ),
        _sandboxed_sdks_debug_key = attr.label(
            allow_single_file = True,
            default = Label("//tools/android:debug_keystore"),
        ),
    ),
    _attrs.ANDROID_SDK,
)

ANDROID_FEATURE_MODULE_ATTRS = dict(
    binary = attr.label(aspects = [android_feature_module_validation_aspect]),
    feature_name = attr.string(),
    library = attr.label(
        allow_rules = ["android_library"],
        cfg = android_split_transition,
        mandatory = True,
        doc = "android_library target to include as a feature split.",
    ),
    manifest = attr.label(allow_single_file = True),
    title_id = attr.string(),
    title_lib = attr.string(),
    fused = attr.bool(),
    _feature_module_validation_script = attr.label(
        allow_single_file = True,
        cfg = "exec",
        executable = True,
        default = ":feature_module_validation.sh",
    ),
    is_asset_pack = attr.bool(
        default = False,
        doc = "Marks the feature module as an asset module. This enables the module to be distributed as archive files rather than just as APKs. Cannot contain any dex or native code.",
    ),
)
