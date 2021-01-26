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

ATTRS = _attrs.replace(
    _attrs.add(
        dict(
            deps = attr.label_list(
                allow_files = True,
                allow_rules = [
                    "aar_import",
                    "android_library",
                    "cc_library",
                    "java_import",
                    "java_library",
                    "java_lite_proto_library",
                ],
                providers = [
                    [CcInfo],
                    [JavaInfo],
                    ["AndroidResourcesInfo", "AndroidAssetsInfo"],
                ],
                cfg = android_common.multi_cpu_configuration,
            ),
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
            resource_configuration_filters = attr.string_list(),
            densities = attr.string_list(),
            nocompress_extensions = attr.string_list(),
            shrink_resources = _attrs.tristate.create(
                default = _attrs.tristate.auto,
            ),
            _defined_resource_files = attr.bool(default = False),
            _enable_manifest_merging = attr.bool(default = True),
        ),
        _attrs.COMPILATION,
        _attrs.DATA_CONTEXT,
    ),
    # TODO(b/167599192): don't override manifest attr to remove .xml file restriction.
    manifest = attr.label(
        allow_single_file = True,
    ),
)
