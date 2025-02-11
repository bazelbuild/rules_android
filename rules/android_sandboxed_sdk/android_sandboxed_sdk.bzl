# Copyright 2023 The Bazel Authors. All rights reserved.
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
"""android_sandboxed_sdk rule.

This file exists to inject the correct version of android_binary.
"""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//rules/android_binary:rule.bzl", _android_binary_macro = "android_binary_macro")
load(":android_sandboxed_sdk_macro.bzl", _android_sandboxed_sdk_macro = "android_sandboxed_sdk_macro")

visibility(PROJECT_VISIBILITY)

def android_sandboxed_sdk(
        name,
        sdk_modules_config,
        deps,
        min_sdk_version,
        target_sdk_version = 34,
        visibility = None,
        testonly = None,
        tags = [],
        custom_package = None,
        proguard_specs = []):
    """Rule to build an Android Sandboxed SDK.

    A sandboxed SDK is a collection of libraries that can run independently in the Privacy Sandbox
    or in a separate split APK of an app. See:
    https://developer.android.com/design-for-safety/privacy-sandbox.

    Args:
      name: Unique name of this target.
      sdk_modules_config: Module config for this SDK. For full definition see
        https://github.com/google/bundletool/blob/master/src/main/proto/sdk_modules_config.proto
      deps: Set of android libraries that make up this SDK.
      min_sdk_version: Min SDK version for the SDK.
      target_sdk_version: Target SDK version for the SDK.
      visibility: A list of targets allowed to depend on this rule.
      testonly: Whether this library is only for testing.
      tags: A list of string tags passed to generated targets.
      custom_package: Java package for which java sources will be generated. By default the package
        is inferred from the directory where the BUILD file containing the rule is. You can specify
        a different package but this is highly discouraged since it can introduce classpath
        conflicts with other libraries that will only be detected at runtime.
      proguard_specs: Proguard specs to use for the SDK. If specified, will also include an implicitly generated spec.
    """

    _android_sandboxed_sdk_macro(
        name = name,
        sdk_modules_config = sdk_modules_config,
        deps = deps,
        min_sdk_version = min_sdk_version,
        target_sdk_version = target_sdk_version,
        visibility = visibility,
        testonly = testonly,
        tags = tags,
        custom_package = custom_package,
        proguard_specs = proguard_specs,
        android_binary = _android_binary_macro,
    )
