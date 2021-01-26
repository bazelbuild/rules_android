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
    "@rules_android//rules:attrs.bzl",
    _attrs = "attrs",
)

ATTRS = _attrs.add(
    dict(
        deps = attr.label_list(
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
        ),
        enable_data_binding = attr.bool(default = False),
        exported_plugins = attr.label_list(
            allow_rules = [
                "java_plugin",
            ],
            cfg = "host",
        ),
        exports = attr.label_list(
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
        ),
        exports_manifest =
            _attrs.tristate.create(default = _attrs.tristate.no),
        idl_import_root = attr.string(),
        idl_parcelables = attr.label_list(allow_files = [".aidl"]),
        idl_preprocessed = attr.label_list(allow_files = [".aidl"]),
        idl_srcs = attr.label_list(allow_files = [".aidl"]),
        neverlink = attr.bool(default = False),
        proguard_specs = attr.label_list(allow_files = True),
        srcs = attr.label_list(
            allow_files = [".java", ".srcjar"],
        ),
        # TODO(b/127517031): Remove these entries once fixed.
        _defined_assets = attr.bool(default = False),
        _defined_assets_dir = attr.bool(default = False),
        _defined_idl_import_root = attr.bool(default = False),
        _defined_idl_parcelables = attr.bool(default = False),
        _defined_idl_srcs = attr.bool(default = False),
        _defined_local_resources = attr.bool(default = False),
        _java_toolchain = attr.label(
            cfg = "host",
            default = Label("//tools/jdk:toolchain_android_only"),
        ),
        # TODO(str): Remove when fully migrated to android_instrumentation_test
        _android_test_migration = attr.bool(default = False),
        _flags = attr.label(
            default = "@rules_android//rules/flags",
        ),
    ),
    _attrs.COMPILATION,
    _attrs.DATA_CONTEXT,
)
