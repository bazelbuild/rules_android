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

load("//providers:reexport_providers.bzl", "providers")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)



AndroidAppsInfo = provider(
    doc = "Provides information about app to install.",
    fields = dict(
        apps = "List of app provider artifacts.",
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

        # Dynamic resources field
        resource_apks = "A depset of resource only apk files",

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
        transitive_resource_apks = "Depset of transitive resource only apk files",
        package = "String, the package used for the generated Java resources",
    ),
)

AndroidLintRulesInfo = provider(
    doc = "Provides extra lint rules to use with AndroidLint.",
    fields = dict(
        lint_jars = "A depset of lint rule jars found in AARs and exported by a target.",
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
        is_asset_pack = "Boolean, whether this feature module is an asset pack. AI packs are a type of asset pack.",
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

StarlarkAndroidDexInfo = provider(
    doc = "Internal provider used to collect transitive dex info.",
    fields = dict(
        dex_archives_dict = (
            "A dictionary of all the transitive dex archives for all dexopts."
        ),
    ),
)

# TODO(b/325299751): The provider is only used for testing purposes now. Change the name to
# AndroidIdeInfo when it's fully Starlarkified in all Android rules.
# buildifier: disable=name-conventions
StarlarkAndroidIdeInfoForTesting = provider(
    doc = "Provides Android-specific information for IDEs",
    fields = dict(
        java_package = "A string of the Java package.",
        manifest = "A file of the Android manifest.",
        generated_manifest = "A file of the generated Android manifest.",
        idl_import_root = "A string of the idl import root.",
        idl_srcs = "A list of files of the idl generated java files.",
        idl_generated_java_files = "A list of files of the idl generated java files.",
        idl_source_jar = "A file of the source Jar with the idl generated java files.",
        idl_class_jar = "A file of the class Jar with the compiled idl generated java files.",
        defines_android_resources = "A boolean if target specifies Android resources.",
        resource_jar = "A struct of type JavaOutput containing Android resources JavaInfo outputs.",
        resource_apk = "A file of the Apk containing Android resources.",
        signed_apk = "A file of the signed Apk.",
        aar = "A file of the Android archive.",
        apks_under_test = "A list of files of the apks under test",
        native_libs = "A dictionary of string to a list of files mapping architectures to" +
                      "native libs.",
    ),
)

ApkInfo = provider(
    doc = "ApkInfo",
    fields = dict(
        signing_lineage = "Returns the signing lineage file, if present, that was used to sign the APK.",
        keystore = "Returns a keystore that was used to sign the APK. Deprecated: prefer signing_keys.",
        coverage_metadata = "Returns the coverage metadata artifact generated in the transitive closure.",
        deploy_jar = "Returns the deploy jar used to build the APK.",
        unsigned_apk = "Returns a unsigned APK built from the target.",
        signed_apk = "Returns a signed APK built from the target.",
        signing_keys = "Returns a list of signing keystores that were used to sign the APK.",
        signing_min_v3_rotation_api_version = "Returns the minimum API version for signing the APK with key rotation.",
    ),
)

AndroidLibraryAarInfo = provider(
    doc = "AndroidLibraryAarInfo",
    fields = dict(
        aar = "The aar.",
    ),
)

AndroidBinaryNativeLibsInfo = provider(
    doc = "AndroidBinaryNativeLibsInfo",
    fields = dict(
        native_libs = "",
        native_libs_name = "",
        transitive_native_libs = "",
    ),
)

AndroidNativeLibsInfo = provider(
    doc = "AndroidNativeLibsInfo",
    fields = dict(
        native_libs = "Returns the native libraries produced by the rule.",
    ),
)

AndroidIdlInfo = provider(
    doc = "AndroidIdlInfo",
    fields = dict(
        transitive_idl_import_roots = "Returns a depset of strings of all the idl import roots.",
        transitive_idl_imports = "Returns a depset of artifacts of all the idl imports.",
        transitive_idl_preprocessed = "Returns a depset of artifacts of all the idl preprocessed files.",
    ),
)

AndroidCcLinkParamsInfo = provider(
    doc = "AndroidCcLinkParamsInfo",
    fields = dict(
        link_params = "",
    ),
)

AndroidDexInfo = provider(
    doc = "AndroidDexInfo",
    fields = dict(
        deploy_jar = "The deploy jar.",
        filtered_deploy_jar = "The filtered deploy jar.",
        final_classes_dex_zip = "The zip file containing the final dex classes.",
        final_proguard_output_map = "The final proguard output map.",
        java_resource_jar = "The final Java resource jar.",
    ),
)

AndroidPreDexJarInfo = provider(
    doc = "AndroidPreDexJarInfo",
    fields = dict(
        pre_dex_jar = "",
    ),
)

# buildifier: disable=name-conventions
AndroidFeatureFlagSet = provider(
    doc = "AndroidFeatureFlagSet",
    fields = dict(
        flags = "Returns the flags contained by the provider.",
    ),
)

AndroidInstrumentationInfo = provider(
    doc = "AndroidInstrumentationInfo",
    fields = dict(
        target = "Returns the target ApkInfo of the instrumentation test.",
    ),
)

# buildifier: disable=name-conventions
BaselineProfileProvider = provider(
    doc = "BaselineProfileProvider",
    fields = dict(
        files = "",
    ),
)

# buildifier: disable=name-conventions
AndroidLibraryResourceClassJarProvider = provider(
    doc = "AndroidLibraryResourceClassJarProvider",
    fields = dict(
        jars = "",
    ),
)

ProguardMappingInfo = provider(
    doc = "ProguardMappingInfo",
    fields = dict(
        proguard_mapping = "",
    ),
)

DataBindingV2Info = provider(
    doc = "DataBindingV2Info",
    fields = dict(
        class_infos = "",
        setter_stores = "",
        transitive_br_files = "",
        java_packages = "List of the Java packages of this rule and any rules that this rule exports.",
    ),
)

AndroidSandboxedSdkInfo = provider(
    doc = "Provides information about a sandboxed Android SDK.",
    fields = dict(
        internal_apk_info = "ApkInfo for SDKs dexes and resources. Note: it cannot " +
                            "be installed on a device as is. It needs to be further processed by " +
                            "other sandboxed SDK rules.",
        sdk_module_config = "The SDK Module config. For the full definition see " +
                            "https://github.com/google/bundletool/blob/master/src/main/proto/sdk_modules_config.proto",
        sdk_api_descriptors = "Jar file with the SDK API Descriptors. This can later be used to " +
                              "generate sources for communicating with this SDK from the app " +
                              "process.",
    ),
)

AndroidArchivedSandboxedSdkInfo = provider(
    doc = "Provides information about an Android Sandboxed SDK archive.",
    fields = dict(
        asar = "Android Sandboxed SDK archive file, as generated by Bundletool.",
        sdk_api_descriptors = "Jar file with the SDK API Descriptors. This can later be used to " +
                              "generate sources for communicating with this SDK from the app " +
                              "process.",
    ),
)

AndroidSandboxedSdkBundleInfo = provider(
    doc = "Provides information about a sandboxed Android SDK Bundle (ASB).",
    fields = dict(
        sdk_info = "AndroidSandboxedSdkInfo with information about the SDK.",
        asb = "Path to the final ASB, unsigned.",
    ),
)

AndroidSandboxedSdkApkInfo = provider(
    doc = "Provides information about App and Sandboxed SDK APKs.",
    fields = dict(
        app_apk_info = "ApkInfo for the host app.",
        sandboxed_sdk_apks = "List of APKs for sandboxed SDK dependencies of the host app. " +
                             "Only present when compat splits are not requested. APKs are signed " +
                             "with debug keys.",
        sandboxed_sdk_splits = "List of APK splits that contain the sandboxed SDK dependencies " +
                               "of the host app. Only present when compat splits are requested.",
    ),
)

# buildifier: disable=name-conventions
def _AndroidIdeInfo_init(
        java_package,
        manifest,
        generated_manifest,
        idl_import_root,
        idl_srcs,
        idl_generated_java_files,
        idl_source_jar,
        idl_class_jar,
        defines_android_resources,
        resource_jar,
        resource_apk,
        signed_apk,
        aar,
        apks_under_test,
        native_libs):
    return {
        "java_package": java_package,
        "manifest": manifest,
        "generated_manifest": generated_manifest,
        "idl_import_root": idl_import_root,
        "idl_srcs": idl_srcs,
        "idl_generated_java_files": idl_generated_java_files,
        "idl_source_jar": idl_source_jar,
        "idl_class_jar": idl_class_jar,
        "defines_android_resources": defines_android_resources,
        "resource_jar": resource_jar,
        "resource_apk": resource_apk,
        "signed_apk": signed_apk,
        "aar": aar,
        "apks_under_test": apks_under_test,
        "native_libs": native_libs,
    }

# buildifier: disable=name-conventions
AndroidIdeInfo, _AndroidIdeInfo_raw = provider(
    init = _AndroidIdeInfo_init,
    doc = "AndroidIdeInfo",
    fields = dict(
        java_package = "",
        manifest = "",
        generated_manifest = "",
        idl_import_root = "",
        idl_srcs = "",
        idl_generated_java_files = "",
        idl_source_jar = "",
        idl_class_jar = "",
        defines_android_resources = "",
        resource_jar = "",
        resource_apk = "",
        signed_apk = "",
        aar = "",
        apks_under_test = "",
        native_libs = "",
    ),
)

# Native defined providers which will be gradually migrated to Starlark.
# We re-export these here so that all our providers can be loaded from this file.
AndroidResourcesInfo = providers.AndroidResourcesInfo
AndroidSdkInfo = providers.AndroidSdkInfo
AndroidManifestInfo = providers.AndroidManifestInfo
AndroidAssetsInfo = providers.AndroidAssetsInfo
