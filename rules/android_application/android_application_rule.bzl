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

load(
    "//providers:providers.bzl",
    "AndroidArchivedSandboxedSdkInfo",
    "AndroidBundleInfo",
    "AndroidFeatureModuleInfo",
    "AndroidIdeInfo",
    "AndroidPreDexJarInfo",
    "AndroidSandboxedSdkBundleInfo",
    "ApkInfo",
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
    _log = "log",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@rules_java//java/common:java_common.bzl", "java_common")
load(":android_feature_module_rule.bzl", "get_feature_module_paths")
load(":attrs.bzl", "ANDROID_APPLICATION_ATTRS")

visibility(PROJECT_VISIBILITY)

UNSUPPORTED_ATTRS = [
    "srcs",
]

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
        application_id = None):
    manifest = _create_feature_manifest(
        ctx,
        base_apk,
        java_package,
        feature_target,
        get_android_sdk(ctx).aapt2,
        ctx.executable._feature_manifest_script,
        ctx.executable._priority_feature_manifest_script,
        get_android_toolchain(ctx).android_resources_busybox,
        _common.get_host_javabase(ctx),
    )

    # Remove all dexes from the feature module apk. jvm / resources are not
    # supported in feature modules. The android_feature_module rule has
    # already validated that there are no transitive sources / resources, but
    # we may get dexes via e.g. the legacy dex or the record globals.
    binary = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "_filtered.apk")
    _common.filter_zip_exclude(
        ctx,
        output = binary,
        input = feature_target[AndroidFeatureModuleInfo].binary[ApkInfo].unsigned_apk,
        filter_types = [".dex"],
    )
    res = feature_target[AndroidFeatureModuleInfo].library[StarlarkAndroidResourcesInfo]
    has_native_libs = bool(feature_target[AndroidFeatureModuleInfo].binary[AndroidIdeInfo].native_libs)
    is_asset_pack = bool(feature_target[AndroidFeatureModuleInfo].is_asset_pack)

    # Create res .proto-apk_, output depending on whether further manipulations
    # are required after busybox. This prevents action conflicts.
    if has_native_libs or is_asset_pack:
        res_apk = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/res.proto-ap_")
    else:
        res_apk = out
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
        should_throw_on_conflict = True,
        application_id = application_id,
    )

    if not is_asset_pack and not has_native_libs:
        return

    if is_asset_pack:
        # Return AndroidManifest.xml and assets from res-ap_
        _common.filter_zip_include(ctx, res_apk, out, ["AndroidManifest.xml", "assets/*"])
    else:
        # Extract libs/ from split binary
        native_libs = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/native_libs.zip")
        _common.filter_zip_include(ctx, binary, native_libs, ["lib/*"])

        # Extract AndroidManifest.xml and assets from res-ap_
        filtered_res = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/filtered_res.zip")
        _common.filter_zip_include(ctx, res_apk, filtered_res, ["AndroidManifest.xml", "assets/*"])

        # Merge into output
        _java.singlejar(
            ctx,
            inputs = [filtered_res, native_libs],
            output = out,
            java_toolchain = _common.get_java_toolchain(ctx),
        )

def _create_feature_manifest(
        ctx,
        base_apk,
        java_package,
        feature_target,
        aapt2,
        feature_manifest_script,
        priority_feature_manifest_script,
        android_resources_busybox,
        host_javabase):
    info = feature_target[AndroidFeatureModuleInfo]
    manifest = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/AndroidManifest.xml")

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

        ctx.actions.run(
            executable = feature_manifest_script,
            inputs = [base_apk],
            outputs = [manifest],
            arguments = [args],
            tools = [
                aapt2,
            ],
            mnemonic = "GenFeatureManifest",
            progress_message = "Generating AndroidManifest.xml for " + feature_target.label.name,
            toolchain = None,
        )
        return manifest

    # Rule has a manifest (already validated by android_feature_module).
    # Generate a priority manifest and then merge the user supplied manifest.
    is_asset_pack = feature_target[AndroidFeatureModuleInfo].is_asset_pack
    priority_manifest = ctx.actions.declare_file(
        ctx.label.name + "/" + feature_target.label.name + "/Priority_AndroidManifest.xml",
    )
    args = ctx.actions.args()
    args.add(priority_manifest.path)
    args.add(base_apk.path)
    args.add(java_package)
    args.add(info.feature_name)
    args.add(aapt2.executable)
    args.add(info.manifest)
    args.add(is_asset_pack)

    ctx.actions.run(
        executable = priority_feature_manifest_script,
        inputs = [base_apk, info.manifest],
        outputs = [priority_manifest],
        arguments = [args],
        tools = [
            aapt2,
        ],
        mnemonic = "GenPriorityFeatureManifest",
        progress_message = "Generating Priority AndroidManifest.xml for " + feature_target.label.name,
        toolchain = None,
    )

    args = ctx.actions.args()
    args.add("--main_manifest", priority_manifest.path)
    args.add("--feature_manifest", info.manifest.path)
    args.add("--feature_title", "@string/" + info.title_id)
    args.add("--out", manifest.path)
    if is_asset_pack:
        args.add("--is_asset_pack")
    ctx.actions.run(
        executable = ctx.attr._merge_manifests.files_to_run,
        inputs = [priority_manifest, info.manifest],
        outputs = [manifest],
        arguments = [args],
        toolchain = None,
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
    _aapt.convert(
        ctx,
        out = base_proto_apk,
        input = base_apk,
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

    # Convert each feature to module zip.
    for feature in ctx.attr.feature_modules:
        proto_apk = ctx.actions.declare_file(
            "%s.proto-ap_" % feature.label.name,
            sibling = base_proto_apk,
        )
        _process_feature_module(
            ctx,
            out = proto_apk,
            base_apk = base_apk,
            feature_target = feature,
            java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package),
            application_id = ctx.attr.manifest_values.get("applicationId"),
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
    if ProguardMappingInfo in ctx.attr.base_module:
        metadata["com.android.tools.build.obfuscation/proguard.map"] = ctx.attr.base_module[ProguardMappingInfo].proguard_mapping

    if ctx.file.device_group_config:
        metadata["com.android.tools.build.bundletool/DeviceGroupConfig.pb"] = ctx.file.device_group_config

    if ctx.file.rotation_config:
        metadata["com.google.play.apps.signing/RotationConfig.textproto"] = ctx.file.rotation_config

    if ctx.file.app_integrity_config:
        metadata["com.google.play.apps.integrity/AppIntegrityConfig.pb"] = ctx.file.app_integrity_config

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
            ] + deploy_script_files, transitive_files = java_runtime.files),
        ),
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
    base_split_name = "%s_base" % name

    # bundle_config is deprecated in favor of bundle_config_file
    # In the future bundle_config will accept a build rule rather than a raw file.
    bundle_config_file = bundle_config_file or bundle_config

    deps = attrs.pop("deps", [])
    for feature_module in feature_modules:
        if not feature_module.startswith("//") or ":" not in feature_module:
            _log.error("feature_modules expects fully qualified paths, i.e. //some/path:target")
        module_targets = get_feature_module_paths(feature_module)
        deps = deps + [str(module_targets.title_lib)]

    _android_binary(
        name = base_split_name,
        deps = deps,
        **attrs
    )

    android_application(
        name = name,
        base_module = ":%s" % base_split_name,
        bundle_config_file = bundle_config_file,
        app_integrity_config = app_integrity_config,
        device_group_config = device_group_config,
        rotation_config = rotation_config,
        custom_package = attrs.get("custom_package", None),
        testonly = attrs.get("testonly"),
        transitive_configs = attrs.get("transitive_configs", []),
        feature_modules = feature_modules,
        sdk_archives = sdk_archives,
        sdk_bundles = sdk_bundles,
        manifest_values = attrs.get("manifest_values"),
        visibility = attrs.get("visibility", None),
        tags = attrs.get("tags", []),
    )
