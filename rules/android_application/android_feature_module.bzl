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

"""android_feature_module rule.

This file exists to inject the correct version of android_binary and android_library.
"""

load(
    ":android_feature_module_rule.bzl",
    _android_feature_module_macro = "android_feature_module_macro",
)
load(
    "@rules_android//rules:android_binary.bzl",
    _android_binary = "android_binary",
)
load(
    "@rules_android//rules/android_library:rule.bzl",
    _android_library_macro = "android_library_macro",
)

def android_feature_module(**attrs):
    """Macro to declare a Dynamic Feature Module.

    Generates the following:

    * strings.xml containing a unique split identifier (currently a hash of the fully qualified target label)
    * dummy AndroidManifest.xml for the split
    * `android_library` to create the split resources
    * `android_feature_module` rule to be consumed by `android_application`

    **Attributes**

    Name | Description
    --- | ---
    name | Required string, split name
    custom_package | Optional string, custom package for this split
    manifest | Required label, the AndroidManifest.xml to use for this module.
    library | Required label, the `android_library` contained in this split. Must only contain assets.
    title | Required string, the split title
    feature_flags | Optional dict, pass through feature_flags dict for native split binary.
    """
    _android_feature_module_macro(
        _android_binary = _android_binary,
        _android_library = _android_library_macro,
        **attrs
    )
