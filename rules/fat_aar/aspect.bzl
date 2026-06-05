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

"""Aspect for collecting transitive Android providers."""

load("@rules_java//java/common:proguard_spec_info.bzl", "ProguardSpecInfo")
load("//providers:providers.bzl", "AndroidAssetsInfo", "AndroidNativeLibsInfo", "AndroidResourcesInfo", "StarlarkAndroidResourcesInfo")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

FatAarInfo = provider(
    "Collects Android providers from transitive dependencies",
    fields = {
        "resource_infos": "Depset of (label, AndroidResourcesInfo) tuples",
        "assets_infos": "Depset of (label, AndroidAssetsInfo) tuples",
        "native_libs_infos": "Depset of (label, AndroidNativeLibsInfo) tuples",
        "manifest_infos": "Depset of (label, manifest_file) tuples",
        "proguard_infos": "Depset of (label, ProguardSpecInfo) tuples",
    },
)

FatAarDependenciesInfo = provider(
    "Tracks dependencies that were excluded during fat_aar bundling",
    fields = {
        "excluded_labels": "Depset of labels that were excluded",
    },
)

def _fat_aar_aspect_impl(target, ctx):
    """Collects Android providers transitively.

    Args:
      target: The target being visited
      ctx: The aspect context

    Returns:
      List containing FatAarInfo provider
    """
    resource_infos = []
    assets_infos = []
    native_libs_infos = []
    manifest_infos = []
    proguard_infos = []

    # Collect providers with their source label
    label = ctx.label

    # Collect both AndroidResourcesInfo and StarlarkAndroidResourcesInfo
    if AndroidResourcesInfo != None and AndroidResourcesInfo in target:
        resource_infos.append((label, target[AndroidResourcesInfo]))
    if StarlarkAndroidResourcesInfo in target:
        resource_infos.append((label, target[StarlarkAndroidResourcesInfo]))
    if AndroidAssetsInfo != None and AndroidAssetsInfo in target:
        assets_infos.append((label, target[AndroidAssetsInfo]))
    if AndroidNativeLibsInfo in target:
        native_libs_infos.append((label, target[AndroidNativeLibsInfo]))
    if ProguardSpecInfo in target:
        proguard_infos.append((label, target[ProguardSpecInfo]))

    # Collect manifest if available
    if hasattr(ctx.rule.attr, "manifest") and ctx.rule.attr.manifest:
        if hasattr(ctx.rule.attr.manifest, "files"):
            for f in ctx.rule.attr.manifest.files.to_list():
                manifest_infos.append((label, f))

    transitive_resource_infos = []
    transitive_assets_infos = []
    transitive_native_libs_infos = []
    transitive_manifest_infos = []
    transitive_proguard_infos = []

    # Collect from deps and exports attributes (declared in attr_aspects)
    for dep in ctx.rule.attr.deps:
        transitive_resource_infos.append(dep[FatAarInfo].resource_infos)
        transitive_assets_infos.append(dep[FatAarInfo].assets_infos)
        transitive_native_libs_infos.append(dep[FatAarInfo].native_libs_infos)
        transitive_manifest_infos.append(dep[FatAarInfo].manifest_infos)
        transitive_proguard_infos.append(dep[FatAarInfo].proguard_infos)

    if hasattr(ctx.rule.attr, "exports"):
        for dep in ctx.rule.attr.exports:
            transitive_resource_infos.append(dep[FatAarInfo].resource_infos)
            transitive_assets_infos.append(dep[FatAarInfo].assets_infos)
            transitive_native_libs_infos.append(dep[FatAarInfo].native_libs_infos)
            transitive_manifest_infos.append(dep[FatAarInfo].manifest_infos)
            transitive_proguard_infos.append(dep[FatAarInfo].proguard_infos)

    return [FatAarInfo(
        resource_infos = depset(resource_infos, transitive = transitive_resource_infos),
        assets_infos = depset(assets_infos, transitive = transitive_assets_infos),
        native_libs_infos = depset(native_libs_infos, transitive = transitive_native_libs_infos),
        manifest_infos = depset(manifest_infos, transitive = transitive_manifest_infos),
        proguard_infos = depset(proguard_infos, transitive = transitive_proguard_infos),
    )]

fat_aar_aspect = aspect(
    implementation = _fat_aar_aspect_impl,
    attr_aspects = ["deps", "exports"],
    provides = [FatAarInfo],
)
