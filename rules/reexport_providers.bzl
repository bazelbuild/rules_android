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
"""A workaround to expose native Android providers to bzl files.

Redefine native symbols with a new name.
"""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

providers = struct(
    ApkInfo = ApkInfo,
    AndroidInstrumentationInfo = AndroidInstrumentationInfo,
    AndroidResourcesInfo = AndroidResourcesInfo,
    AndroidApplicationResourceInfo = AndroidApplicationResourceInfo,
    AndroidSdkInfo = AndroidSdkInfo,
    AndroidManifestInfo = AndroidManifestInfo,
    AndroidAssetsInfo = AndroidAssetsInfo,
    AndroidIdeInfo = AndroidIdeInfo,
    AndroidPreDexJarInfo = AndroidPreDexJarInfo,
    AndroidCcLinkParamsInfo = AndroidCcLinkParamsInfo,
    DataBindingV2Info = DataBindingV2Info,
    AndroidLibraryResourceClassJarProvider = AndroidLibraryResourceClassJarProvider,
    AndroidFeatureFlagSet = AndroidFeatureFlagSet,
    ProguardMappingInfo = ProguardMappingInfo,
    BaselineProfileProvider = BaselineProfileProvider,
    AndroidDexInfo = AndroidDexInfo,
    AndroidOptimizationInfo = AndroidOptimizationInfo,
)
