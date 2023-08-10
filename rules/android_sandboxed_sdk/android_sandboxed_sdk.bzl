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

load(":android_sandboxed_sdk_macro.bzl", _android_sandboxed_sdk_macro = "android_sandboxed_sdk_macro")
load("//rules:android_binary.bzl", _android_binary = "android_binary")

def android_sandboxed_sdk(
        name,
        sdk_modules_config,
        deps,
        min_sdk_version = 21,
        custom_package = None):
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
      custom_package: Java package for which java sources will be generated. By default the package
        is inferred from the directory where the BUILD file containing the rule is. You can specify
        a different package but this is highly discouraged since it can introduce classpath
        conflicts with other libraries that will only be detected at runtime.
    """

    _android_sandboxed_sdk_macro(
        name = name,
        sdk_modules_config = sdk_modules_config,
        deps = deps,
        min_sdk_version = min_sdk_version,
        custom_package = custom_package,
        android_binary = _android_binary,
    )
