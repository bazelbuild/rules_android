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

"""Bazel providers for Android rules."""



AndroidAppsInfo = provider(
    doc = "Provides information about app to install.",
    fields = dict(
        apps = "List of app provider artifacts.",
    ),
)








AndroidJavaInfo = provider(
    doc = "Provides outputs for the Android Java Compilation",
    fields = dict(
        aidl = "AndroidIdlInfo",
        aide = "AndroidIdeInfo",
        java = "JavaInfo",
    ),
)

AndroidFilteredJdepsInfo = provider(
    doc = "Provides a filtered jdeps proto.",
    fields = dict(
        jdeps = "Filtered jdeps",
    ),
)


StarlarkApkInfo = provider(
    doc = "Provides APK outputs of a rule.",
    fields = dict(
        keystore = "Keystore used to sign the APK. Deprecated, prefer signing_keys.",
        signing_keys = "List of keys used to sign the APK",
        signing_lineage = "Optional sigining lineage file",
        signed_apk = "Signed APK",
        unsigned_apk = "Unsigned APK",
    ),
)

ResourcesNodeInfo = provider(
    doc = "Provides information for building ResourceProcessorBusyBox flags",
    fields = dict(
        label = "A label, the target's label",

        # Assets related fields
        assets = "A depset of files, assets files of the target",
        assets_dir = "A string, the name of the assets directory",
        assets_symbols = "A file, the merged assets",
        compiled_assets = "A file, the compiled assets",

        # Resource related fields
        resource_files = "A depset of files, resource files of the target",
        compiled_resources = "A file, the compiled resources",
        r_txt = "A file, the R.txt file",
        manifest = "A file, the AndroidManifest.xml",
        # TODO(ostonge): Add the manifest if it's exported, otherwise leave empty
        exports_manifest = "Boolean, whether the manifest is exported",
    ),
)

StarlarkAndroidResourcesInfo = provider(
    doc = "Provides information about direct and transitive resources",
    fields = dict(
        direct_resources_nodes = "Depset of ResourcesNodeInfo providers, can contain multiple providers due to exports",
        transitive_resources_nodes = "Depset of transitive ResourcesNodeInfo providers, not including directs",
        transitive_assets = "Depset of transitive assets files",
        transitive_assets_symbols = "Depset of transitive merged assets",
        transitive_compiled_assets = "Depset of transitive compiled assets",
        direct_compiled_resources = "Depset of direct compiled_resources, can contain multiple files due to exports",
        transitive_compiled_resources = "Depset of transitive compiled resources",
        transitive_manifests = "Depset of transitive manifests",
        transitive_r_txts = "Depset of transitive R.txt files",
        transitive_resource_files = "Depset of transitive resource files",
        packages_to_r_txts = "Map of packages to depset of r_txt files",
    ),
)

AndroidLintRulesInfo = provider(
    doc = "Provides extra lint rules to use with AndroidLint.",
    fields = dict(
        lint_jar = "A file, a lint jar found in an aar.",
    ),
)

AndroidFeatureModuleInfo = provider(
    doc = "Contains data required to build an Android feature split.",
    fields = dict(
        binary = "String, target of the underlying split android_binary target",
        feature_name = "String, the name of the feature module. If unspecified, the target name will be used.",
        fused = "Boolean, whether the split is \"fused\" for the system image and for pre-L devices.",
        library = "String, target of the underlying split android_library target",
        manifest = "Optional AndroidManifest.xml file to use for this feature.",
        min_sdk_version = "String, the min SDK version for this feature.",
        title_id = "String, resource identifier for the split title.",
        title_lib = "String, target of the split title android_library.",
    ),
)


Dex2OatApkInfo = provider(
    doc = "Contains data about artifacts generated through host dex2oat.",
    fields = dict(
        signed_apk = "Signed APK",
        oat_file = "Oat file generated through dex2oat.",
        vdex_file = "Vdex file generated through dex2oat.",
        art_file = "ART file generated through dex2oat.",
    ),
)

InstrumentedAppInfo = provider(
    doc = "Contains data about an android_binary's instrumented android_binary.",
    fields = dict(
        android_ide_info = "AndroidIdeInfo provider from the instrumented android_binary.",
    ),
)

FailureInfo = provider(
    fields = dict(
        error = "Error message",
    ),
)

AndroidBundleInfo = provider(
    doc = "Provides .aab outputs from a rule.",
    fields = dict(
        unsigned_aab = "File, the unsigned .aab",
    ),
)
