# Copyright 2024 The Bazel Authors. All rights reserved.
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
"""Additional flag definitions."""

load("@bazel_skylib//rules:common_settings.bzl", "bool_flag", "string_flag")

def additional_flags():

    # Determines the order of manifest merging. 'dependency' means the order
    # of 'deps', and 'legacy' means the legacy alphabetizing and inverted
    # direct/transitive order.
    string_flag(
        name = "manifest_merge_order",
        build_setting_default = "dependency",
        values = [
            "legacy",
            "dependency",
        ],
        visibility = ["//visibility:public"],
    )

    bool_flag(
        name = "databinding_use_androidx",
        build_setting_default = False,
        visibility = ["//visibility:public"],
    )
