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

load(":android_feature_module_rule.bzl", "get_feature_module_paths")
load(":attrs.bzl", "ANDROID_APPLICATION_ATTRS")
load(
    "@rules_android//rules:aapt.bzl",
    _aapt = "aapt",
)
load(
    "@rules_android//rules:bundletool.bzl",
    _bundletool = "bundletool",
)
load(
    "@rules_android//rules:busybox.bzl",
    _busybox = "busybox",
)
load(
    "@rules_android//rules:common.bzl",
    _common = "common",
)
load(
    "@rules_android//rules:java.bzl",
    _java = "java",
)
load(
    "@rules_android//rules:providers.bzl",
    "AndroidBundleInfo",
    "AndroidFeatureModuleInfo",
    "StarlarkAndroidResourcesInfo",
)
load(
    "@rules_android//rules:utils.bzl",
    "get_android_toolchain",
    _log = "log",
)

UNSUPPORTED_ATTRS = [
    "srcs",
]

def _verify_attrs(attrs, fqn):
    for attr in UNSUPPORTED_ATTRS:
        if hasattr(attrs, attr):
            _log.error("Unsupported attr: %s in android_application" % attr)

    if not attrs.get("manifest_values", default = {}).get("applicationId"):
        _log.error("%s missing required applicationId in manifest_values" % fqn)

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
        ctx.attr._android_sdk[AndroidSdkInfo].aapt2,
        ctx.executable._feature_manifest_script,
        ctx.executable._priority_feature_manifest_script,
        get_android_toolchain(ctx).android_resources_busybox,
        _common.get_host_javabase(ctx),
    )
    res = feature_target[AndroidFeatureModuleInfo].library[StarlarkAndroidResourcesInfo]
    binary = feature_target[AndroidFeatureModuleInfo].binary[ApkInfo].unsigned_apk
    has_native_libs = bool(feature_target[AndroidFeatureModuleInfo].binary[AndroidIdeInfo].native_libs)

    # Create res .proto-apk_, output depending on whether this split has native libs.
    if has_native_libs:
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
        android_jar = ctx.attr._android_sdk[AndroidSdkInfo].android_jar,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
        should_throw_on_conflict = True,
        application_id = application_id,
    )

    if not has_native_libs:
        return

    # Extract libs/ from split binary
    native_libs = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/native_libs.zip")
    _common.filter_zip(ctx, binary, native_libs, ["lib/*"])

    # Extract AndroidManifest.xml and assets from res-ap_
    filtered_res = ctx.actions.declare_file(ctx.label.name + "/" + feature_target.label.name + "/filtered_res.zip")
    _common.filter_zip(ctx, res_apk, filtered_res, ["AndroidManifest.xml", "assets/*"])

    # Merge into output
    _java.singlejar(
        ctx,
        inputs = [filtered_res, native_libs],
        output = out,
        exclude_build_data = True,
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
        )
        return manifest

    # Rule has a manifest (already validated by android_feature_module).
    # Generate a priority manifest and then merge the user supplied manifest.
    priority_manifest = ctx.actions.declare_file(
        ctx.label.name + "/" + feature_target.label.name + "/Prioriy_AndroidManifest.xml",
    )
    args = ctx.actions.args()
    args.add(priority_manifest.path)
    args.add(base_apk.path)
    args.add(java_package)
    args.add(info.feature_name)
    args.add(aapt2.executable)
    ctx.actions.run(
        executable = priority_feature_manifest_script,
        inputs = [base_apk],
        outputs = [priority_manifest],
        arguments = [args],
        tools = [
            aapt2,
        ],
        mnemonic = "GenPriorityFeatureManifest",
        progress_message = "Generating Priority AndroidManifest.xml for " + feature_target.label.name,
    )

    _busybox.merge_manifests(
        ctx,
        out_file = manifest,
        manifest = priority_manifest,
        mergee_manifests = depset([info.manifest]),
        java_package = java_package,
        busybox = android_resources_busybox.files_to_run,
        host_javabase = host_javabase,
        manifest_values = {"MODULE_TITLE": "@string/" + info.title_id},
    )

    return manifest

def _impl(ctx):
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
    proto_apks = [base_proto_apk]

    # Convert each feature to .proto-ap_
    for feature in ctx.attr.feature_modules:
        feature_proto_apk = ctx.actions.declare_file(
            "%s.proto-ap_" % feature.label.name,
            sibling = base_proto_apk,
        )
        _process_feature_module(
            ctx,
            out = feature_proto_apk,
            base_apk = base_apk,
            feature_target = feature,
            java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package),
            application_id = ctx.attr.application_id,
        )
        proto_apks.append(feature_proto_apk)

    # Convert each each .proto-ap_ to module zip
    modules = []
    for proto_apk in proto_apks:
        module = ctx.actions.declare_file(
            proto_apk.basename + ".zip",
            sibling = proto_apk,
        )
        modules.append(module)
        _bundletool.proto_apk_to_module(
            ctx,
            out = module,
            proto_apk = proto_apk,
            unzip = get_android_toolchain(ctx).unzip_tool.files_to_run,
            zip = get_android_toolchain(ctx).zip_tool.files_to_run,
        )

    metadata = dict()
    if ProguardMappingInfo in ctx.attr.base_module:
        metadata["com.android.tools.build.obfuscation/proguard.map"] = ctx.attr.base_module[ProguardMappingInfo].proguard_mapping

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
    subs = {
        "%bundletool_path%": get_android_toolchain(ctx).bundletool.files_to_run.executable.short_path,
        "%aab%": ctx.outputs.unsigned_aab.short_path,
        "%key%": ctx.attr.base_module[ApkInfo].signing_keys[0].short_path,
    }
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
                ctx.attr.base_module[ApkInfo].signing_keys[0],
                get_android_toolchain(ctx).bundletool.files_to_run.executable,
            ]),
        ),
    ]

android_application = rule(
    attrs = ANDROID_APPLICATION_ATTRS,
    fragments = [
        "android",
        "java",
    ],
    executable = True,
    implementation = _impl,
    outputs = {
        "deploy_script": "%{name}.sh",
        "unsigned_aab": "%{name}_unsigned.aab",
    },
    toolchains = ["@rules_android//toolchains/android:toolchain_type"],
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
    app_integrity_config = attrs.pop("app_integrity_config", default = None)
    rotation_config = attrs.pop("rotation_config", default = None)

    # Simply fall back to android_binary if no feature splits or bundle_config
    if not attrs.get("feature_modules", None) and not (attrs.get("bundle_config", None) or attrs.get("bundle_config_file", None)):
        _android_binary(**attrs)
        return

    _verify_attrs(attrs, fqn)

    # Create an android_binary base split, plus an android_application to produce the aab
    name = attrs.pop("name")
    base_split_name = "%s_base" % name

    # default to [] if feature_modules = None is passed
    feature_modules = attrs.pop("feature_modules", default = []) or []
    bundle_config = attrs.pop("bundle_config", default = None)
    bundle_config_file = attrs.pop("bundle_config_file", default = None)

    # bundle_config is deprecated in favor of bundle_config_file
    # In the future bundle_config will accept a build rule rather than a raw file.
    bundle_config_file = bundle_config_file or bundle_config

    for feature_module in feature_modules:
        if not feature_module.startswith("//") or ":" not in feature_module:
            _log.error("feature_modules expects fully qualified paths, i.e. //some/path:target")
        module_targets = get_feature_module_paths(feature_module)
        attrs["deps"].append(str(module_targets.title_lib))

    _android_binary(
        name = base_split_name,
        **attrs
    )

    android_application(
        name = name,
        base_module = ":%s" % base_split_name,
        bundle_config_file = bundle_config_file,
        app_integrity_config = app_integrity_config,
        rotation_config = rotation_config,
        custom_package = attrs.get("custom_package", None),
        testonly = attrs.get("testonly"),
        transitive_configs = attrs.get("transitive_configs", []),
        feature_modules = feature_modules,
        application_id = attrs["manifest_values"]["applicationId"],
    )
