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

"""android_application rule.

This file exists to inject the correct version of android_binary.
"""

load(":android_application_rule.bzl", _android_application_macro = "android_application_macro")
load("@rules_android//rules:android_binary.bzl", _android_binary = "android_binary")

def android_application(**attrs):
    """Rule to build an Android Application (app bundle).

    `android_application` produces an app bundle (.aab) rather than an apk, and treats splits
    (both configuration and dynamic feature modules) as first-class constructs. If
    `feature_modules`, `bundle_config` or both are supplied this rule will produce an .aab.
    Otherwise it will fall back to `android_binary` and produce an apk.

    **Attributes**

    `android_application` accepts all the same attributes as `android_binary`, with the following
    key differences.

    Name | Description
    --- | ---
    `srcs` | `android_application` does not accept sources.
    `manifest_values` | Required. Must specify `applicationId` in the `manifest_values`
    `feature_modules` | New. List of labels to `android_feature_module`s to include as feature splits. Note: must be fully qualified paths (//some:target), not relative.
    `bundle_config_file` | New. String path to .pb.json file containing the bundle config. See the [bundletool docs](https://developer.android.com/studio/build/building-cmdline#bundleconfig) for format and examples. Note: this attribute is subject to changes which may require teams to migrate their configurations to a build target.
    `app_integrity_config` | Optional. String path to .binarypb file containing the play integrity config. See https://github.com/google/bundletool/blob/master/src/main/proto/app_integrity_config.proto.
    `rotation_config` | Optional. String path to .textproto file containing the V3 rotation config.

    Args:
          **attrs: Rule attributes
    """
    _android_application_macro(
        _android_binary = _android_binary,
        **attrs
    )
