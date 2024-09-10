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
"""Temporary export of providers."""

load(
    "//providers:providers.bzl",
    _AndroidAssetsInfo = "AndroidAssetsInfo",
    _AndroidBundleInfo = "AndroidBundleInfo",
    _AndroidDeviceInfo = "AndroidDeviceInfo",
    _AndroidDeviceScriptFixtureInfo = "AndroidDeviceScriptFixtureInfo",
    _AndroidHostServiceFixtureInfo = "AndroidHostServiceFixtureInfo",
    _AndroidIdeInfo = "AndroidIdeInfo",
    _AndroidInstrumentationInfo = "AndroidInstrumentationInfo",
    _AndroidLibraryAarInfo = "AndroidLibraryAarInfo",
    _AndroidManifestInfo = "AndroidManifestInfo",
    _AndroidNativeLibsInfo = "AndroidNativeLibsInfo",
    _AndroidResourcesInfo = "AndroidResourcesInfo",
    _AndroidSdkInfo = "AndroidSdkInfo",
    _ApkInfo = "ApkInfo",
    _ProguardMappingInfo = "ProguardMappingInfo",
    _StarlarkAndroidResourcesInfo = "StarlarkAndroidResourcesInfo",
    _StarlarkDex2OatInfo = "StarlarkDex2OatInfo",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

AndroidAssetsInfo = _AndroidAssetsInfo
AndroidBundleInfo = _AndroidBundleInfo
AndroidDeviceInfo = _AndroidDeviceInfo
AndroidDeviceScriptFixtureInfo = _AndroidDeviceScriptFixtureInfo
AndroidHostServiceFixtureInfo = _AndroidHostServiceFixtureInfo
AndroidIdeInfo = _AndroidIdeInfo
AndroidInstrumentationInfo = _AndroidInstrumentationInfo
AndroidLibraryAarInfo = _AndroidLibraryAarInfo
AndroidManifestInfo = _AndroidManifestInfo
AndroidNativeLibsInfo = _AndroidNativeLibsInfo
AndroidResourcesInfo = _AndroidResourcesInfo
AndroidSdkInfo = _AndroidSdkInfo
ApkInfo = _ApkInfo
ProguardMappingInfo = _ProguardMappingInfo
StarlarkAndroidResourcesInfo = _StarlarkAndroidResourcesInfo
StarlarkDex2OatInfo = _StarlarkDex2OatInfo
