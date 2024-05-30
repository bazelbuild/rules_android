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

"""Bazel mobile-install providers."""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)
MIAppInfo = provider(
    doc = "A provider with all relevant details about an app",
    fields = dict(
        manifest_package_name = "A file containing the manifest package name",
        merged_manifest = "The Merged manifest file",
        splits = "The split apk files for the app",
        r_dex = "The R dex files",
        merged_dex_shards = "The Merged dex shards",
        dex_shards = "The dex files for the app",
        native_zip = "The native zip file",
        apk = "The generated android.apk path for the app",
    ),
)

MIAppLaunchInfo = provider(
    doc = "A provider with launching details about an app",
    fields = dict(
        launcher = "The launcher file",
        launcher_flags = "The flagfile for the app",
        runfiles = "The list of files needed to launch an app",
    ),
)

MIAndroidAarNativeLibsInfo = provider(
    doc = "Provides Android AAR native libs information",
    fields = dict(
        transitive_native_libs = (
            "A depset containing the native libs provided by all the " +
            "aar_import rules within the transitive closure of the target."
        ),
    ),
)

MIAndroidAssetsInfo = provider(
    doc = "Provider Android Assets information",
    fields = dict(
        transitive_assets = (
            "A depset of assets in the transitive closure of the target."
        ),
        transitive_assets_dirs = (
            "A depset of assets dirs in the transitive closure of the target."
        ),
    ),
)

MIAndroidDexInfo = provider(
    doc = "Provides Android Dex information",
    fields = dict(
        transitive_dex_shards = (
            "A list of depsets each containing all of the shard level " +
            "dexes in the transitive closure of the target."
        ),
    ),
)

MIAndroidResourcesInfo = provider(
    doc = "Provider Android Resources information",
    fields = dict(
        resources_graph = (
            "Build up a resource graph so that it may be orderd in a bfs" +
            "manner (and deps list order)."
        ),
        transitive_packages = (
            "A depset of package names in the transitive closure of the target."
        ),
        r_java_info = "The JavaInfo for an R.jar",
        transitive_r_pbs = "The transitive R.pb files.",
    ),
)

MIAndroidSdkInfo = provider(
    doc = "Provides android_sdk rule information",
    fields = dict(
        aidl_lib = "The aidl_lib attribute of an android_sdk rule.",
    ),
)

MIJavaResourcesInfo = provider(
    doc = "Provider Java Resources information",
    fields = dict(
        transitive_java_resources = (
            "A depset of all the Java resources in the transitive closure of " +
            "the target."
        ),
    ),
)

def _collect(provider_type, *all_deps):
    providers = []
    for deps in all_deps:
        for dep in deps:
            if provider_type in dep:
                providers.append(dep[provider_type])
    return providers

def _make_mi_android_aar_native_libs_info(
        native_libs = None,
        deps = []):
    transitive_native_libs = [native_libs] if native_libs else []
    for info in deps:
        transitive_native_libs.append(info.transitive_native_libs)

    return MIAndroidAarNativeLibsInfo(
        transitive_native_libs = depset(transitive = transitive_native_libs),
    )

def _make_mi_android_assets_info(
        assets = depset(),
        assets_dir = None,
        deps = []):
    transitive_assets = []
    transitive_assets_dirs = []
    for info in deps:
        transitive_assets.append(info.transitive_assets)
        transitive_assets_dirs.append(info.transitive_assets_dirs)
    return MIAndroidAssetsInfo(
        transitive_assets = depset(
            transitive = [assets] + transitive_assets,
        ),
        transitive_assets_dirs = depset(
            ([assets_dir] if assets_dir else []),
            transitive = transitive_assets_dirs,
        ),
    )

def _make_mi_android_dex_info(
        dex_shards = [],
        deps = []):
    dex_buckets = dict()
    for shards in dex_shards:
        for idx, shard in enumerate(shards):
            dex_buckets.setdefault(idx, []).append(shard)

    transitive_dexes_per_shard = dict()
    for info in deps:
        if not info.transitive_dex_shards:
            continue
        for idx, dex_shard in enumerate(info.transitive_dex_shards):
            transitive_dexes_per_shard.setdefault(idx, []).append(dex_shard)

    transitive_dex_shards = []
    for idx in range(len(dex_buckets) or len(transitive_dexes_per_shard)):
        transitive_dex_shards.append(
            depset(
                dex_buckets.get(idx, []),
                transitive = transitive_dexes_per_shard.get(idx, []),
                order = "preorder",
            ),
        )

    return MIAndroidDexInfo(transitive_dex_shards = transitive_dex_shards)

def _make_mi_android_resources_info(
        package = None,
        label = None,
        r_pb = None,
        resources = depset(),
        deps = []):
    resources_subgraphs = []
    transitive_packages = []
    transitive_r_pbs = []
    for info in deps:
        resources_subgraphs.append(info.resources_graph)
        transitive_packages.append(info.transitive_packages)
        transitive_r_pbs.append(info.transitive_r_pbs)
    return MIAndroidResourcesInfo(
        resources_graph = (label, resources, resources_subgraphs),
        transitive_packages = depset(
            ([package] if package else []),
            transitive = transitive_packages,
        ),
        transitive_r_pbs = depset(
            ([r_pb] if r_pb else []),
            transitive = transitive_r_pbs,
        ),
    )

def _make_mi_java_resources_info(
        java_resources = [],
        deps = []):
    transitive_java_resources = []
    for info in deps:
        transitive_java_resources.append(info.transitive_java_resources)

    return MIJavaResourcesInfo(
        transitive_java_resources = depset(
            java_resources,
            transitive = transitive_java_resources,
        ),
    )

providers = struct(
    collect = _collect,
    make_mi_android_aar_native_libs_info = _make_mi_android_aar_native_libs_info,
    make_mi_android_assets_info = _make_mi_android_assets_info,
    make_mi_android_dex_info = _make_mi_android_dex_info,
    make_mi_android_resources_info = _make_mi_android_resources_info,
    make_mi_java_resources_info = _make_mi_java_resources_info,
)
