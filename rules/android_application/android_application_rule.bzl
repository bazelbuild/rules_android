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
"""android_application rule."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_java//java/common:proguard_spec_info.bzl", "ProguardSpecInfo")
load(
    "//providers:providers.bzl",
    "AndroidApplicationResourceInfo",
    "AndroidArchivedSandboxedSdkInfo",
    "AndroidBinaryNativeLibsInfo",
    "AndroidBundleInfo",
    "AndroidFeatureModuleInfo",
    "AndroidIdeInfo",
    "AndroidOptimizationInfo",
    "AndroidPreDexJarInfo",
    "AndroidSandboxedSdkBundleInfo",
    "ApkInfo",
    "ArtProfileInfo",
    "ProguardMappingInfo",
    "StarlarkAndroidResourcesInfo",
)
load(
    "//rules:aapt.bzl",
    _aapt = "aapt",
)
load("//rules:acls.bzl", _acls = "acls")
load("//rules:android_platforms_transition.bzl", "android_platforms_transition")
load(
    "//rules:bundletool.bzl",
    _bundletool = "bundletool",
)
load(
    "//rules:busybox.bzl",
    _busybox = "busybox",
)
load(
    "//rules:common.bzl",
    _common = "common",
)
load(
    "//rules:java.bzl",
    _java = "java",
)
load(
    "//rules:sandboxed_sdk_toolbox.bzl",
    _sandboxed_sdk_toolbox = "sandboxed_sdk_toolbox",
)
load(
    "//rules:utils.bzl",
    "ANDROID_SDK_TOOLCHAIN_TYPE",
    "get_android_sdk",
    "get_android_toolchain",
    "utils",
    _log = "log",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":android_feature_module_rule.bzl", "get_feature_module_paths")
load(":attrs.bzl", "ANDROID_APPLICATION_ATTRS")
load("//rules:r8.bzl", _r8 = "r8")

visibility(PROJECT_VISIBILITY)

UNSUPPORTED_ATTRS = [
    "srcs",
]

_EMPTY_ZIP = "UEsFBgAAAAAAAAAAAAAAAAAAAAAAAA=="

def _verify_attrs(attrs, fqn):
    for attr in UNSUPPORTED_ATTRS:
        if hasattr(attrs, attr):
            _log.error("Unsupported attr: %s in android_application" % attr)

    for attr in ["deps"]:
        if attr not in attrs:
            _log.error("%s missing require attribute `%s`" % (fqn, attr))

def _process_feature_module(
        ctx,
        out = None,
        base_apk = None,
        feature_target = None,
        java_package = None,
        application_id = None,
        r8_feature_map = None,
        base_module_paths = []):

    dex_archives = []
    apk_info = feature_target[AndroidFeatureModuleInfo].binary[ApkInfo]
    optimized_dex = r8_feature_map.get(apk_info.deploy_jar)
    feature_name = optimized_dex.path.split("/")[-1].lower() if optimized_dex else feature_target.label.name
    dex_zip = ctx.actions.declare_file(ctx.label.name + "/" + feature_name + "/classes.dex.zip")
    zip_tool = get_android_toolchain(ctx).zip_tool.files_to_run

    if optimized_dex:
        ctx.actions.run_shell(
            tools = [zip_tool],
            inputs = [optimized_dex],
            outputs = [dex_zip],
            command = """#!/bin/sh
if [ ! -f "{dex_dir}/classes.dex" ]; then
    echo "{empty_zip}" | base64 -d >  "{dex_zip}"
else
    find {dex_dir} -exec touch -t 199609240000 {{}} \\;
    {zip_tool} -X -j -r -q {dex_zip} {dex_dir}
fi
            """.format(
                empty_zip = _EMPTY_ZIP,
                zip_tool = zip_tool.executable.path,
                dex_zip = dex_zip.path,
                dex_dir = optimized_dex.path,
            ),
            mnemonic = "ZipDex",
            progress_message = "Zipping optimized dex %s" % optimized_dex.path,
        )
        dex_archives = [dex_zip]
    else:
        # extract dex files from the feature module apk or create an empty zip if there are no dex files
        unzip_tool = get_android_toolchain(ctx).unzip_tool.files_to_run
        ctx.actions.run_shell(
            tools = [unzip_tool, zip_tool],
            inputs = [apk_info.unsigned_apk],
            outputs = [dex_zip],
            command = """#!/bin/sh
    {unzip_tool} -l {unsigned_apk} "classes*.dex"
    unzip=$?
    if [[ "${{unzip}}" != 0 ]]; then
        echo "{empty_zip}" | base64 -d >  "{dex_zip}"
    else
        {zip_tool} -q {unsigned_apk} "classes*.dex" --copy --out {dex_zip}
    fi
            """.format(
                empty_zip = _EMPTY_ZIP,
                zip_tool = zip_tool.executable.path,
                unzip_tool = unzip_tool.executable.path,
                dex_zip = dex_zip.path,
                unsigned_apk = apk_info.unsigned_apk.path,
            ),
            mnemonic = "ZipDex",
            progress_message = "Zipping dex %s" % dex_zip.path,
        )
        dex_archives = [dex_zip]

    manifest = _create_feature_manifest(
        ctx,
        base_apk,
        java_package,
        feature_target,
        feature_name,
        dex_zip,
        base_module_paths,
        get_android_sdk(ctx).aapt2,
        ctx.executable._feature_manifest_script,
        ctx.executable._priority_feature_manifest_script,
        get_android_toolchain(ctx).android_resources_busybox,
        _common.get_host_javabase(ctx),
    )

    res = feature_target[AndroidFeatureModuleInfo].library[StarlarkAndroidResourcesInfo]
    binary = feature_target[AndroidFeatureModuleInfo].binary[ApkInfo].unsigned_apk
    _feature_unique_name = feature_target[AndroidFeatureModuleInfo].feature_name

    # Create res .proto-apk_ (always as a separate file to avoid bundletool entry clash)
    res_apk = ctx.actions.declare_file(ctx.label.name + "/" + _feature_unique_name + "/res.proto-ap_")
    _busybox.package(
        ctx,
        out_r_src_jar = ctx.actions.declare_file("R.srcjar", sibling = manifest),
        out_r_txt = ctx.actions.declare_file("R.txt", sibling = manifest),
        out_symbols = ctx.actions.declare_file("merged.bin", sibling = manifest),
        out_manifest = ctx.actions.declare_file("AndroidManifest_processed.xml", sibling = manifest),
        out_proguard_cfg = ctx.actions.declare_file("proguard.cfg", sibling = manifest),
        out_main_dex_proguard_cfg = ctx.actions.declare_file(
            "main_dex_proguard.cfg",
            sibling = manifest,
        ),
        out_resource_files_zip = ctx.actions.declare_file("resource_files.zip", sibling = manifest),
        out_file = res_apk,
        manifest = manifest,
        java_package = java_package,
        direct_resources_nodes = res.direct_resources_nodes,
        transitive_resources_nodes = res.transitive_resources_nodes,
        transitive_manifests = [res.transitive_manifests],
        transitive_assets = [res.transitive_assets],
        transitive_compiled_assets = [res.transitive_compiled_assets],
        transitive_resource_files = [res.transitive_resource_files],
        transitive_compiled_resources = [res.transitive_compiled_resources],
        transitive_r_txts = [res.transitive_r_txts],
        additional_apks_to_link_against = [base_apk],
        proto_format = True,  # required for aab.
        android_jar = get_android_sdk(ctx).android_jar,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
        should_throw_on_conflict = False,
        debug = False,
        application_id = application_id,
    )

    # Extract libs/ from split binary (two-step: include then exclude manifest)
    native_lib_tmp = ctx.actions.declare_file(ctx.label.name + "/" + _feature_unique_name + "/native_libs_tmp.zip")
    _common.filter_zip_include(ctx, binary, native_lib_tmp, ["lib/*", "AndroidManifest.xml"])
    native_lib = ctx.actions.declare_file(ctx.label.name + "/" + _feature_unique_name + "/native_libs.zip")
    _common.filter_zip_exclude(ctx, native_lib, native_lib_tmp, filters = ["AndroidManifest.xml"])
    native_libs = [native_lib]

    # Extract only AndroidManifest.xml and assets from res-ap_ (no res/ files to avoid bundletool clash)
    filtered_res = ctx.actions.declare_file(ctx.label.name + "/" + _feature_unique_name + "/filtered_res.zip")
    _common.filter_zip_include(ctx, res_apk, filtered_res, ["AndroidManifest.xml", "assets/*"])

    # Merge dex + native libs + manifest/assets into one zip
    merged_jar = ctx.actions.declare_file(ctx.label.name + "/" + _feature_unique_name + "/merged.zip")
    _java.singlejar(
        ctx,
        inputs = dex_archives + native_libs + [filtered_res],
        output = merged_jar,
        java_toolchain = _common.get_java_toolchain(ctx),
    )

    # Filter out classes/resources already present in the base to avoid duplication
    inputs = [base_apk, merged_jar]
    args = ctx.actions.args()
    args.add(out.path)
    args.add(base_apk.path)
    args.add(merged_jar.path)
    args.add("^lib/|^assets/|META-INF/MANIFEST.MF")
    ctx.actions.run(
        executable = ctx.executable._filter_feature_classes_script,
        inputs = inputs,
        outputs = [out],
        arguments = [args],
        mnemonic = "FilterResFeatureModule",
        progress_message = "Filtering resource jar for feature module '%s'" % feature_name,
        toolchain = None,
    )

def _create_r8_output_directories(ctx):
    jar_to_dir = dict()
    for module in ctx.attr.feature_modules:
        name = module[AndroidFeatureModuleInfo].feature_name
        output_dir = ctx.actions.declare_directory(
                ctx.label.name + "/proguarded_modules/" + name
        )

        deploy_jar = module[AndroidFeatureModuleInfo].binary[ApkInfo].deploy_jar
        jar_to_dir[deploy_jar] = output_dir
    return jar_to_dir

def _module_path(artifact):
    path = artifact.short_path.replace("/_migrated", "")
    if path.startswith("../"):
        path = path.replace("_processed_manifest/AndroidManifest.xml", "").replace("_resources.jar", "")
    else:
        path = path.replace("/_migrated", "").replace("/AndroidManifest.xml", "")
        path, _, _ = path.rpartition("/")
    return path

def _create_feature_manifest(
        ctx,
        base_apk,
        java_package,
        feature_target,
        feature_name,
        dex_zip,
        base_module_paths,
        aapt2,
        feature_manifest_script,
        priority_feature_manifest_script,
        android_resources_busybox,
        host_javabase):
    info = feature_target[AndroidFeatureModuleInfo]
    manifest = ctx.actions.declare_file(ctx.label.name + "/" + feature_name + "/AndroidManifest.xml")

    # Only include manifest not already present in base module
    transitive_manifests = []
    for transitive_manifest in info.library[StarlarkAndroidResourcesInfo].transitive_manifests.to_list():
        manifest_module_path = _module_path(transitive_manifest)
        if manifest_module_path not in base_module_paths:
            transitive_manifests.append(transitive_manifest)

    manifest_to_merge = None
    # Rule has not specified a manifest. Populate the default manifest template.
    if not info.manifest:
        args = ctx.actions.args()
        args.add(manifest.path)
        args.add(base_apk.path)
        args.add(java_package)
        args.add(info.feature_name)
        args.add(info.title_id)
        args.add(info.fused)
        args.add(aapt2.executable)
        args.add(dex_zip)

        ctx.actions.run(
            executable = feature_manifest_script,
            inputs = [base_apk],
            outputs = [manifest],
            arguments = [args],
            tools = [
                aapt2,
            ],
            mnemonic = "GenFeatureManifest",
            progress_message = "Generating AndroidManifest.xml for " + feature_name,
            toolchain = None,
        )
        manifest_to_merge = manifest
    else:
        # Rule has a manifest (already validated by android_feature_module).
        # Generate a priority manifest and then merge the user supplied manifest.
        priority_manifest = ctx.actions.declare_file(
            ctx.label.name + "/" + feature_name + "/Prioriy_AndroidManifest.xml",
        )
        args = ctx.actions.args()
        args.add(priority_manifest.path)
        args.add(base_apk.path)
        args.add(info.manifest.path)
        args.add(info.feature_name)
        args.add(aapt2.executable)
        args.add(dex_zip)
        ctx.actions.run(
            executable = priority_feature_manifest_script,
            inputs = [info.manifest, base_apk, dex_zip],
            outputs = [priority_manifest],
            arguments = [args],
            tools = [
                aapt2,
            ],
            mnemonic = "GenPriorityFeatureManifest",
            progress_message = "Generating Priority AndroidManifest.xml for " + feature_name,
            toolchain = None,
        )

        manifest_to_merge = ctx.actions.declare_file(ctx.label.name + "/" + feature_name + "/feature_AndroidManifest.xml")
        args = ctx.actions.args()
        args.add("--main_manifest", priority_manifest.path)
        args.add("--feature_manifest", info.manifest.path)
        args.add("--feature_title", "@string/" + info.title_id)
        args.add("--out", manifest_to_merge.path)
        ctx.actions.run(
            executable = ctx.attr._merge_manifests.files_to_run,
            inputs = [priority_manifest, info.manifest],
            outputs = [manifest_to_merge],
            arguments = [args],
            toolchain = None,
        )

    _busybox.merge_manifests(
        ctx,
        out_file = manifest,
        out_log_file = ctx.actions.declare_file(
            ctx.label.name + "/%s_feature_manifest_merger_log.txt" % info.feature_name,
        ),
         manifest = manifest_to_merge,
         mergee_manifests = depset(transitive_manifests),
         manifest_values = {"MODULE_TITLE": "@string/" + info.title_id},
         manifest_merge_order = ctx.attr._manifest_merge_order[BuildSettingInfo].value,
         merge_type = "APPLICATION",
         java_package = java_package,
         busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
         host_javabase =  _common.get_host_javabase(ctx),
    )
    return manifest

def _generate_runtime_enabled_sdk_config(ctx, base_proto_apk):
    module_configs = [
        bundle[AndroidSandboxedSdkBundleInfo].sdk_info.sdk_module_config
        for bundle in ctx.attr.sdk_bundles
    ]
    sdk_archives = [
        archive[AndroidArchivedSandboxedSdkInfo].asar
        for archive in ctx.attr.sdk_archives
    ]
    if not (sdk_archives or module_configs):
        return None

    debug_key = ctx.file._sandboxed_sdks_debug_key
    manifest_xml_tree = ctx.actions.declare_file(ctx.label.name + "/manifest_tree_dump.txt")
    _aapt.dump_manifest_xml_tree(
        ctx,
        out = manifest_xml_tree,
        apk = base_proto_apk,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
    )

    config = ctx.actions.declare_file("%s/runtime-enabled-sdk-config.pb" % ctx.label.name)
    _sandboxed_sdk_toolbox.generate_runtime_enabled_sdk_config(
        ctx,
        output = config,
        manifest_xml_tree = manifest_xml_tree,
        sdk_module_configs = module_configs,
        sdk_archives = sdk_archives,
        debug_key = debug_key,
        sandboxed_sdk_toolbox = get_android_toolchain(ctx).sandboxed_sdk_toolbox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )
    return config

def _validate_manifest_values(manifest_values):
    if "applicationId" not in manifest_values:
        _log.error("missing required applicationId in manifest_values")

def _impl(ctx):
    _validate_manifest_values(ctx.attr.manifest_values)

    # Convert base apk to .proto_ap_
    base_apk = ctx.attr.base_module[ApkInfo].unsigned_apk
    base_proto_apk = ctx.actions.declare_file(ctx.label.name + "/modules/base.proto-ap_")

    r8_feature_map = dict()
    android_dex_info = None
    baseline_profile_info = None
    if ctx.attr.proguard_specs:
        r8_feature_map = _create_r8_output_directories(ctx)
        main_deploy_jar = ctx.attr.base_module[ApkInfo].deploy_jar

        proguard_specs = []
        for specs in ctx.files.proguard_specs:
            proguard_specs.append(specs)

        # Include base module's resource proguard config (keeps Android components from manifest)
        base_resource_info = ctx.attr.base_module[AndroidApplicationResourceInfo]
        if base_resource_info.resource_proguard_config:
            proguard_specs.append(base_resource_info.resource_proguard_config)

        all_modules = [ctx.attr.base_module]
        for feature in ctx.attr.feature_modules:
            binary = feature[AndroidFeatureModuleInfo].binary
            if AndroidApplicationResourceInfo in binary:
                proguard_specs.append(binary[AndroidApplicationResourceInfo].resource_proguard_config)
            all_modules.append(feature[AndroidFeatureModuleInfo].library)

        spec_providers = utils.collect_providers(
            ProguardSpecInfo,
            all_modules
        )

        for sp in spec_providers:
            for spec in sp.specs.to_list():
                if spec not in proguard_specs:
                    proguard_specs.append(spec)

        resource_apk = ctx.attr.base_module[AndroidApplicationResourceInfo].resource_apk
        app_resource_info = ctx.attr.base_module[AndroidApplicationResourceInfo]
        android_dex_info, optimisation_info = _r8.process(
                ctx,
                main_deploy_jar,
                app_resource_info,
                proguard_specs,
                startup_profile = ctx.file.startup_profile,
                feature_split_jars = r8_feature_map,
        )

        base_apk = ctx.actions.declare_file(ctx.label.name + "_base_proguarded_unsigned.apk")
        native_libs = depset(transitive = ctx.attr.base_module[AndroidBinaryNativeLibsInfo].transitive_native_libs_by_cpu_architecture.values()).to_list()
        _java.singlejar(
            ctx,
            inputs = [resource_apk, android_dex_info.final_classes_dex_zip] + native_libs,
            output = base_apk,
            include_build_data = False,
            java_toolchain = _common.get_java_toolchain(ctx),
        )

        if optimisation_info:
            optimized_base_apk = ctx.actions.declare_file(ctx.label.name + "_base_proguarded_optimized_unsigned.apk")
            native_libs = depset(transitive = ctx.attr.base_module[AndroidBinaryNativeLibsInfo].transitive_native_libs_by_cpu_architecture.values()).to_list()
            _java.singlejar(
                ctx,
                inputs = [optimisation_info.optimized_resource_apk, android_dex_info.final_classes_dex_zip] + native_libs,
                output = optimized_base_apk,
                include_build_data = False,
                java_toolchain = _common.get_java_toolchain(ctx),
            )

    _aapt.convert(
        ctx,
        out = base_proto_apk,
        input = optimized_base_apk if optimisation_info else base_apk,
        to_proto = True,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
    )

    modules = []
    base_module = ctx.actions.declare_file(
        base_proto_apk.basename + ".zip",
        sibling = base_proto_apk,
    )
    modules.append(base_module)
    _bundletool.proto_apk_to_module(
        ctx,
        out = base_module,
        proto_apk = base_proto_apk,
        # RuntimeEnabledSdkConfig should only be added to the base module.
        runtime_enabled_sdk_config = _generate_runtime_enabled_sdk_config(ctx, base_proto_apk),
        bundletool_module_builder =
            get_android_toolchain(ctx).bundletool_module_builder.files_to_run,
    )

    base_module_paths = []
    for dep in ctx.attr.deps:
        for jar in dep[JavaInfo].transitive_runtime_jars.to_list():
            base_module_paths.append(_module_path(jar))

    # Convert each feature to module zip.
    for feature in ctx.attr.feature_modules:
        proto_apk = ctx.actions.declare_file(
            "%s.proto-ap_" % feature[AndroidFeatureModuleInfo].feature_name,
            sibling = base_proto_apk,
        )
        _process_feature_module(
            ctx,
            out = proto_apk,
            base_apk = base_apk,
            feature_target = feature,
            java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package),
            application_id = ctx.attr.manifest_values.get("applicationId"),
            r8_feature_map = r8_feature_map,
            base_module_paths = base_module_paths,
        )
        module = ctx.actions.declare_file(
            proto_apk.basename + ".zip",
            sibling = proto_apk,
        )
        modules.append(module)
        _bundletool.proto_apk_to_module(
            ctx,
            out = module,
            proto_apk = proto_apk,
            bundletool_module_builder =
                get_android_toolchain(ctx).bundletool_module_builder.files_to_run,
        )

    metadata = dict()
    if ctx.attr.proguard_include_mapping:
        if android_dex_info:
            metadata["com.android.tools.build.obfuscation/proguard.map"] = android_dex_info.final_proguard_output_map

        if ProguardMappingInfo in ctx.attr.base_module:
            metadata["com.android.tools.build.obfuscation/proguard.map"] = ctx.attr.base_module[ProguardMappingInfo].proguard_mapping

    if ctx.file.device_group_config:
        metadata["com.android.tools.build.bundletool/DeviceGroupConfig.json"] = ctx.file.device_group_config

    if ctx.file.rotation_config:
        metadata["com.google.play.apps.signing/RotationConfig.textproto"] = ctx.file.rotation_config

    if ctx.file.app_integrity_config:
        metadata["com.google.play.apps.integrity/AppIntegrityConfig.pb"] = ctx.file.app_integrity_config

    if ArtProfileInfo in ctx.attr.base_module:
        base_art_profile_info = ctx.attr.base_module[ArtProfileInfo]
        metadata["com.android.tools.build.profiles/baseline.prof"] = base_art_profile_info.baseline_profile
        metadata["com.android.tools.build.profiles/baseline.profm"] = base_art_profile_info.baseline_profile_metadata

    if AndroidOptimizationInfo in ctx.attr.base_module:
        opt_info = ctx.attr.base_module[AndroidOptimizationInfo]
        if opt_info.d8_optimization_info:
            metadata["com.android.tools/d8.json"] = opt_info.d8_optimization_info

    # Create .aab
    _bundletool.build(
        ctx,
        out = ctx.outputs.unsigned_aab,
        modules = modules,
        config = ctx.file.bundle_config_file,
        metadata = metadata,
        bundletool = get_android_toolchain(ctx).bundletool.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )

    # Create `blaze run` script
    java_runtime = _common.get_host_javabase(ctx)[java_common.JavaRuntimeInfo]
    base_apk_info = ctx.attr.base_module[ApkInfo]
    deploy_script_files = [base_apk_info.signing_keys[-1]]

    subs = {
        "%java_executable%": java_runtime.java_executable_exec_path,
        "%bundletool_path%": get_android_toolchain(ctx).bundletool.files_to_run.executable.short_path,
        "%aab%": ctx.outputs.unsigned_aab.short_path,
        "%newest_key%": base_apk_info.signing_keys[-1].short_path,
        "%aapt2_path%" : get_android_sdk(ctx).aapt2.executable.short_path,
    }
    if base_apk_info.signing_lineage:
        signer_properties = _common.create_signer_properties(ctx, base_apk_info.signing_keys[0])
        subs["%oldest_signer_properties%"] = signer_properties.short_path
        subs["%lineage%"] = base_apk_info.signing_lineage.short_path
        subs["%min_rotation_api%"] = base_apk_info.signing_min_v3_rotation_api_version
        deploy_script_files.extend(
            [signer_properties, base_apk_info.signing_lineage, base_apk_info.signing_keys[0]],
        )
    else:
        subs["%oldest_signer_properties%"] = ""
        subs["%lineage%"] = ""
        subs["%min_rotation_api%"] = ""
    ctx.actions.expand_template(
        template = ctx.file._bundle_deploy,
        output = ctx.outputs.deploy_script,
        substitutions = subs,
        is_executable = True,
    )

    return [
        ctx.attr.base_module[ApkInfo],
        ctx.attr.base_module[AndroidPreDexJarInfo],
        AndroidBundleInfo(unsigned_aab = ctx.outputs.unsigned_aab),
        DefaultInfo(
            executable = ctx.outputs.deploy_script,
            runfiles = ctx.runfiles([
                ctx.outputs.unsigned_aab,
                get_android_toolchain(ctx).bundletool.files_to_run.executable,
                get_android_sdk(ctx).aapt2.executable,
            ] + deploy_script_files, transitive_files = java_runtime.files),
        ),
        android_dex_info,
    ]

android_application = rule(
    attrs = ANDROID_APPLICATION_ATTRS,
    cfg = android_platforms_transition,
    fragments = [
        "android",
        "bazel_android",  # NOTE: Only exists for Bazel
        "java",
    ],
    executable = True,
    implementation = _impl,
    outputs = {
        "deploy_script": "%{name}.sh",
        "unsigned_aab": "%{name}_unsigned.aab",
    },
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
        ANDROID_SDK_TOOLCHAIN_TYPE,
    ],
    _skylark_testable = True,
)

def android_application_macro(_android_binary, **attrs):
    """android_application_macro.

    Args:
      _android_binary: The android_binary rule to use.
      **attrs: android_application attributes.
    """

    fqn = "//%s:%s" % (native.package_name(), attrs["name"])

    # Must pop these because android_binary does not have these attributes.
    app_integrity_config = attrs.pop("app_integrity_config", None)
    device_group_config = attrs.pop("device_group_config", None)
    rotation_config = attrs.pop("rotation_config", None)

    # default to [] if feature_modules = None is passed
    feature_modules = attrs.pop("feature_modules", []) or []
    bundle_config = attrs.pop("bundle_config", None)
    bundle_config_file = attrs.pop("bundle_config_file", None)
    sdk_archives = attrs.pop("sdk_archives", []) or []
    sdk_bundles = attrs.pop("sdk_bundles", []) or []
    uses_sandboxed_sdks = sdk_archives or sdk_bundles
    if (uses_sandboxed_sdks and
        not _acls.in_android_application_with_sandboxed_sdks_allowlist_dict(fqn)):
        fail("%s is not allowed to use sdk_archives or sdk_bundles." % fqn)

    uses_bundle_features = (
        feature_modules or
        bool(bundle_config) or
        bool(bundle_config_file) or
        uses_sandboxed_sdks
    )

    # Simply fall back to android_binary if no bundle features are used.
    if not uses_bundle_features:
        _android_binary(**attrs)
        return

    _verify_attrs(attrs, fqn)

    # Create an android_binary base split, plus an android_application to produce the aab
    name = attrs.pop("name")

    # bundle_config is deprecated in favor of bundle_config_file
    # In the future bundle_config will accept a build rule rather than a raw file.
    bundle_config_file = bundle_config_file or bundle_config

    modules_titles = []
    deps = attrs.pop("deps", [])
    original_deps = deps
    for feature_module in feature_modules:
        if not feature_module.startswith("//") or ":" not in feature_module:
            _log.error("feature_modules expects fully qualified paths, i.e. //some/path:target")
        module_targets = get_feature_module_paths(feature_module)
        deps = deps + [module_targets.title_lib, module_targets.library_resources_only_lib]
        modules_titles.append(str(module_targets.title_strings_xml))

    # we dont want to proguard the base module. It needs to be proguarded with all the splits.
    proguard_specs = attrs.get("proguard_specs", [])
    startup_profile = attrs.pop("startup_profile", None)

    tags = attrs.pop("tags", [])
    if proguard_specs:
        tags += ["has_proguard_specs"]

    # obfuscate_resources is an android_application attr, not android_binary.
    obfuscate_resources = attrs.pop("obfuscate_resources", False)

    base_name = "%s_internal" % name
    base_module = ":%s" % base_name

    _android_binary(
        name = base_name,
        deps = deps,
        tags = tags,
        **attrs
    )
    
    android_application(
        name = name,
        base_module = base_module,
        bundle_config_file = bundle_config_file,
        app_integrity_config = app_integrity_config,
        device_group_config = device_group_config,
        rotation_config = rotation_config,
        proguard_specs = proguard_specs,
        custom_package = attrs.get("custom_package", None),
        testonly = attrs.get("testonly"),
        transitive_configs = attrs.get("transitive_configs", []),
        feature_modules = feature_modules,
        feature_modules_title_files = modules_titles,
        sdk_archives = sdk_archives,
        sdk_bundles = sdk_bundles,
        startup_profile = startup_profile,
        manifest_values = attrs.get("manifest_values"),
        min_sdk_version = attrs.get("min_sdk_version", None),
        visibility = attrs.get("visibility", None),
        tags = attrs.get("tags", []),
        exec_properties = attrs.get("exec_properties", None),
        deps = original_deps,
        shrink_resources = attrs.get("shrink_resources", False),
        obfuscate_resources = obfuscate_resources,
    )
