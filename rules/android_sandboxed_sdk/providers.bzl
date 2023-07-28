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

"""Providers for Android Sandboxed SDK rules."""

AndroidSandboxedSdkInfo = provider(
    doc = "Provides information about a sandboxed Android SDK.",
    fields = dict(
        internal_apk_info = "ApkInfo for SDKs dexes and resources. Note: it cannot " +
                            "be installed on a device as is. It needs to be further processed by " +
                            "other sandboxed SDK rules.",
        sdk_module_config = "The SDK Module config. For the full definition see " +
                            "https://github.com/google/bundletool/blob/master/src/main/proto/sdk_modules_config.proto",
        # TODO b/291279514 - Add SDK API descriptors to this provider when API packager is ready in
        # Google3 (tracked in b/287193040)
    ),
)

AndroidSandboxedSdkBundleInfo = provider(
    doc = "Provides information about a sandboxed Android SDK Bundle (ASB).",
    fields = dict(
        sdk_info = "AndroidSandboxedSdkInfo with information about the SDK.",
        asb = "Path to the final ASB, unsigned.",
    ),
)
