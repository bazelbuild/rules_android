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

"""Attributes."""

load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
load(
    "//rules:native_deps.bzl",
    "split_config_aspect",
)
load("//rules:providers.bzl", "StarlarkApkInfo")

def make_deps(allow_rules, providers):
    return attr.label_list(
        allow_files = True,
        allow_rules = allow_rules,
        providers = providers,
        cfg = android_common.multi_cpu_configuration,
    )

DEPS_ALLOW_RULES = [
    "aar_import",
    "android_library",
    "cc_library",
    "java_import",
    "java_library",
    "java_lite_proto_library",
]

DEPS_PROVIDERS = [
    [CcInfo],
    [JavaInfo],
    ["AndroidResourcesInfo", "AndroidAssetsInfo"],
]

ATTRS = _attrs.replace(
    _attrs.add(
        dict(
            srcs = attr.label_list(
                # TODO(timpeut): Set PropertyFlag direct_compile_time_input
                allow_files = [".java", ".srcjar"],
            ),
            deps = make_deps(DEPS_ALLOW_RULES, DEPS_PROVIDERS),
            enable_data_binding = attr.bool(),
            instruments = attr.label(),
            manifest_values = attr.string_dict(),
            manifest_merger = attr.string(
                default = "auto",
                values = ["auto", "legacy", "android", "force_android"],
            ),
            native_target = attr.label(
                allow_files = False,
                allow_rules = ["android_binary", "android_test"],
            ),
            proguard_specs = attr.label_list(allow_empty = True, allow_files = True),
            resource_apks = attr.label_list(
                allow_rules = ["apk_import"],
                providers = [
                    [StarlarkApkInfo],
                ],
                doc = (
                    "List of resource only apks to link against."
                ),
            ),
            resource_configuration_filters = attr.string_list(),
            densities = attr.string_list(),
            nocompress_extensions = attr.string_list(),
            shrink_resources = _attrs.tristate.create(
                default = _attrs.tristate.auto,
            ),
            _java_toolchain = attr.label(
                default = Label("//tools/jdk:toolchain_android_only"),
            ),
            _defined_resource_files = attr.bool(default = False),
            _enable_manifest_merging = attr.bool(default = True),
            _cc_toolchain_split = attr.label(
                cfg = android_common.multi_cpu_configuration,
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                aspects = [split_config_aspect],
            ),
            _grep_includes = attr.label(
                allow_single_file = True,
                executable = True,
                cfg = "exec",
                default = Label("@@bazel_tools//tools/cpp:grep-includes"),
            ),
        ),
        _attrs.COMPILATION,
        _attrs.DATA_CONTEXT,
        _attrs.ANDROID_TOOLCHAIN_ATTRS,
    ),
    # TODO(b/167599192): don't override manifest attr to remove .xml file restriction.
    manifest = attr.label(
        allow_single_file = True,
    ),
)
