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

"""Bazel rule for defining an Android binary that depends on sandboxed SDKs."""

load(
    "//rules:aapt.bzl",
    _aapt = "aapt",
)
load("//rules:acls.bzl", "acls")
load("//rules:bundletool.bzl", _bundletool = "bundletool")
load("//rules:common.bzl", _common = "common")
load("//rules:java.bzl", _java = "java")
load(
    "//rules:sandboxed_sdk_toolbox.bzl",
    _sandboxed_sdk_toolbox = "sandboxed_sdk_toolbox",
)
load(
    "//rules:utils.bzl",
    _get_android_toolchain = "get_android_toolchain",
    _utils = "utils",
)
load(":providers.bzl", "AndroidArchivedSandboxedSdkInfo", "AndroidSandboxedSdkApkInfo", "AndroidSandboxedSdkBundleInfo")

def _gen_sdk_dependencies_manifest_impl(ctx):
    manifest = ctx.actions.declare_file(ctx.label.name + "_sdk_dep_manifest.xml")
    module_configs = [
        bundle[AndroidSandboxedSdkBundleInfo].sdk_info.sdk_module_config
        for bundle in ctx.attr.sdk_bundles
    ]
    sdk_archives = [
        archive[AndroidArchivedSandboxedSdkInfo].asar
        for archive in ctx.attr.sdk_archives
    ]

    _sandboxed_sdk_toolbox.generate_sdk_dependencies_manifest(
        ctx,
        output = manifest,
        manifest_package = ctx.attr.package,
        sdk_module_configs = module_configs,
        sdk_archives = sdk_archives,
        debug_key = ctx.file.debug_key,
        sandboxed_sdk_toolbox = _get_android_toolchain(ctx).sandboxed_sdk_toolbox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )

    return [
        DefaultInfo(
            files = depset([manifest]),
        ),
    ]

_gen_sdk_dependencies_manifest = rule(
    attrs = dict(
        package = attr.string(),
        sdk_bundles = attr.label_list(
            providers = [
                [AndroidSandboxedSdkBundleInfo],
            ],
        ),
        sdk_archives = attr.label_list(
            providers = [
                [AndroidArchivedSandboxedSdkInfo],
            ],
        ),
        debug_key = attr.label(
            allow_single_file = True,
            default = Label("//tools/android:debug_keystore"),
        ),
        _host_javabase = attr.label(
            cfg = "exec",
            default = Label("//tools/jdk:current_java_runtime"),
        ),
    ),
    executable = False,
    implementation = _gen_sdk_dependencies_manifest_impl,
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
    ],
)

def _gen_sdk_dependencies_table_asset_impl(ctx):
    runtime_enabled_sdk_metadata = ctx.actions.declare_file(
        "%s/RuntimeEnabledSdkTable.xml" % ctx.attr.assets_dir,
    )
    module_configs = [
        bundle[AndroidSandboxedSdkBundleInfo].sdk_info.sdk_module_config
        for bundle in ctx.attr.sdk_bundles
    ]
    sdk_archives = [
        archive[AndroidArchivedSandboxedSdkInfo].asar
        for archive in ctx.attr.sdk_archives
    ]

    _sandboxed_sdk_toolbox.generate_runtime_enabled_sdk_table(
        ctx,
        output = runtime_enabled_sdk_metadata,
        sdk_archives = sdk_archives,
        sdk_module_configs = module_configs,
        sandboxed_sdk_toolbox = _get_android_toolchain(ctx).sandboxed_sdk_toolbox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )

    return [
        DefaultInfo(
            files = depset([runtime_enabled_sdk_metadata]),
        ),
    ]

_gen_sdk_dependencies_table_asset = rule(
    attrs = dict(
        assets_dir = attr.string(),
        sdk_archives = attr.label_list(
            providers = [
                [AndroidArchivedSandboxedSdkInfo],
            ],
        ),
        sdk_bundles = attr.label_list(
            providers = [
                [AndroidSandboxedSdkBundleInfo],
            ],
        ),
        _host_javabase = attr.label(
            cfg = "exec",
            default = Label("//tools/jdk:current_java_runtime"),
        ),
    ),
    executable = False,
    implementation = _gen_sdk_dependencies_table_asset_impl,
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
    ],
)

def _get_sandboxed_sdk_apks(ctx):
    sdk_apks = []
    for idx, sdk_archive in enumerate(ctx.attr.sdk_archives):
        apk_out = ctx.actions.declare_file("%s/sdk_archive_dep_apks/%s.apk" % (
            ctx.label.name,
            idx,
        ))
        _bundletool.build_sdk_apks(
            ctx,
            out = apk_out,
            aapt2 = _get_android_toolchain(ctx).aapt2.files_to_run,
            sdk_archive = sdk_archive[AndroidArchivedSandboxedSdkInfo].asar,
            debug_key = ctx.file.debug_key,
            bundletool = _get_android_toolchain(ctx).bundletool.files_to_run,
            host_javabase = _common.get_host_javabase(ctx),
        )
        sdk_apks.append(apk_out)

    for idx, sdk_bundle_target in enumerate(ctx.attr.sdk_bundles):
        apk_out = ctx.actions.declare_file("%s/sdk_bundle_dep_apks/%s.apk" % (
            ctx.label.name,
            idx,
        ))
        _bundletool.build_sdk_apks(
            ctx,
            out = apk_out,
            aapt2 = _get_android_toolchain(ctx).aapt2.files_to_run,
            sdk_bundle = sdk_bundle_target[AndroidSandboxedSdkBundleInfo].asb,
            debug_key = ctx.file.debug_key,
            bundletool = _get_android_toolchain(ctx).bundletool.files_to_run,
            host_javabase = _common.get_host_javabase(ctx),
        )
        sdk_apks.append(apk_out)
    return sdk_apks

def _get_runtime_enabled_config(ctx, manifest_xml_tree):
    app_apk_info = ctx.attr.internal_android_binary[ApkInfo]
    module_configs = [
        bundle[AndroidSandboxedSdkBundleInfo].sdk_info.sdk_module_config
        for bundle in ctx.attr.sdk_bundles
    ]
    sdk_archives = [
        archive[AndroidArchivedSandboxedSdkInfo].asar
        for archive in ctx.attr.sdk_archives
    ]

    debug_key = _utils.only(app_apk_info.signing_keys)
    config = ctx.actions.declare_file("%s/runtime-enabled-sdk-config.pb" % ctx.label.name)
    _sandboxed_sdk_toolbox.generate_runtime_enabled_sdk_config(
        ctx,
        output = config,
        manifest_xml_tree = manifest_xml_tree,
        sdk_module_configs = module_configs,
        sdk_archives = sdk_archives,
        debug_key = debug_key,
        sandboxed_sdk_toolbox = _get_android_toolchain(ctx).sandboxed_sdk_toolbox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )
    return config

def _get_split_sdk_apk(
        ctx,
        output_dir_name,
        output_apk_name,
        runtime_enabled_sdk_config,
        manifest_xml_tree,
        sdk_archive_asar = None,
        sdk_bundle = None,
        sdk_module_config = None):
    sdk_split_properties = ctx.actions.declare_file("%s/%s.pb.json" % (
        output_dir_name,
        output_apk_name,
    ))
    _sandboxed_sdk_toolbox.generate_sdk_split_properties(
        ctx,
        output = sdk_split_properties,
        sdk_archive = sdk_archive_asar,
        sdk_module_config = sdk_module_config,
        runtime_enabled_sdk_config = runtime_enabled_sdk_config,
        manifest_xml_tree = manifest_xml_tree,
        sandboxed_sdk_toolbox = _get_android_toolchain(ctx).sandboxed_sdk_toolbox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )

    split = ctx.actions.declare_file("%s/%s.apk" % (
        output_dir_name,
        output_apk_name,
    ))
    _bundletool.build_sdk_apks_for_app(
        ctx,
        out = split,
        aapt2 = _get_android_toolchain(ctx).aapt2.files_to_run,
        sdk_archive = sdk_archive_asar,
        sdk_bundle = sdk_bundle,
        sdk_split_properties_inherited_from_app = sdk_split_properties,
        debug_key = ctx.file.debug_key,
        bundletool = _get_android_toolchain(ctx).bundletool.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )
    return split

def _get_all_split_sdk_apks(ctx):
    manifest_xml_tree = ctx.actions.declare_file(ctx.label.name + "/manifest_tree_dump.txt")
    _aapt.dump_manifest_xml_tree(
        ctx,
        out = manifest_xml_tree,
        apk = ctx.attr.internal_android_binary[ApkInfo].unsigned_apk,
        aapt = _get_android_toolchain(ctx).aapt2.files_to_run,
    )
    runtime_enabled_sdk_config = _get_runtime_enabled_config(ctx, manifest_xml_tree)
    sdk_splits = []
    for idx, sdk_archive_info in enumerate(ctx.attr.sdk_archives):
        sdk_archive = sdk_archive_info[AndroidArchivedSandboxedSdkInfo].asar
        sdk_splits.append(_get_split_sdk_apk(
            ctx,
            output_dir_name = "%s/sdk_archive_splits" % ctx.label.name,
            output_apk_name = idx,
            manifest_xml_tree = manifest_xml_tree,
            runtime_enabled_sdk_config = runtime_enabled_sdk_config,
            sdk_archive_asar = sdk_archive,
        ))
    for idx, sdk_bundle_target in enumerate(ctx.attr.sdk_bundles):
        sdk_bundle_info = sdk_bundle_target[AndroidSandboxedSdkBundleInfo]
        sdk_splits.append(_get_split_sdk_apk(
            ctx,
            output_dir_name = "%s/sdk_bundle_splits" % ctx.label.name,
            output_apk_name = idx,
            manifest_xml_tree = manifest_xml_tree,
            runtime_enabled_sdk_config = runtime_enabled_sdk_config,
            sdk_bundle = sdk_bundle_info.asb,
            sdk_module_config = sdk_bundle_info.sdk_info.sdk_module_config,
        ))
    return sdk_splits

def _android_binary_with_sandboxed_sdks_impl(ctx):
    app_apk = ctx.attr.internal_android_binary[ApkInfo].signed_apk
    adb = _get_android_toolchain(ctx).adb.files_to_run.executable
    substitutions = {
        "%adb%": adb.short_path,
        "%app_apk%": app_apk.short_path,
    }
    install_script = ctx.actions.declare_file("%s_install_script.sh" % ctx.label.name)
    template = None
    sdk_apks = []
    sdk_splits = []

    if ctx.attr.use_compat_splits:
        sdk_splits.extend(_get_all_split_sdk_apks(ctx))
        substitutions["%sdk_splits%"] = ",".join([split.short_path for split in sdk_splits])
        template = ctx.file._install_splits_script_template
    else:
        sdk_apks.extend(_get_sandboxed_sdk_apks(ctx))
        substitutions["%sdk_apks%"] = ",".join([apk.short_path for apk in sdk_apks])
        template = ctx.file._install_apks_script_template

    ctx.actions.expand_template(
        template = template,
        output = install_script,
        substitutions = substitutions,
        is_executable = True,
    )

    return [
        AndroidSandboxedSdkApkInfo(
            app_apk_info = ctx.attr.internal_android_binary[ApkInfo],
            sandboxed_sdk_apks = sdk_apks,
            sandboxed_sdk_splits = sdk_splits,
        ),
        DefaultInfo(
            executable = install_script,
            files = depset([app_apk] + sdk_splits + sdk_apks),
            runfiles = ctx.runfiles([
                adb,
                app_apk,
            ] + sdk_apks + sdk_splits),
        ),
    ]

def _get_extra_dependency_for_sandboxed_apks(
        name,
        app_package,
        sdk_archives,
        sdk_bundles,
        testonly,
        tags,
        transitive_configs,
        visibility,
        _android_library):
    # Generate a manifest that lists all the SDK dependencies with <uses-sdk-library> tags.
    sdk_dependencies_manifest_name = "%s_sdk_dependencies_manifest" % name
    _gen_sdk_dependencies_manifest(
        name = sdk_dependencies_manifest_name,
        package = "%s.internalsdkdependencies" % app_package,
        sdk_bundles = sdk_bundles,
        sdk_archives = sdk_archives,
        testonly = testonly,
        tags = tags,
        visibility = visibility,
    )

    # Use the manifest in a normal android_library. This will later be added as a dependency to the
    # binary, so the manifest is merged with the app's.
    sdk_dependencies_lib_name = "%s_sdk_dependencies_lib" % name
    _android_library(
        name = sdk_dependencies_lib_name,
        exports_manifest = 1,
        manifest = ":%s" % sdk_dependencies_manifest_name,
        testonly = testonly,
        tags = tags,
        transitive_configs = transitive_configs,
        visibility = visibility,
    )

    return ":%s" % sdk_dependencies_lib_name

def _get_extra_dependency_for_split_apks(
        name,
        app_package,
        sdk_archives,
        sdk_bundles,
        testonly,
        tags,
        transitive_configs,
        visibility,
        _android_library):
    assets_dir = "%s/assets" % name
    runtime_enabled_sdk_metadata_asset = "%s_runtime_enabled_sdk_metadata" % name
    _gen_sdk_dependencies_table_asset(
        name = runtime_enabled_sdk_metadata_asset,
        assets_dir = assets_dir,
        sdk_archives = sdk_archives,
        sdk_bundles = sdk_bundles,
        testonly = testonly,
        tags = tags,
        visibility = visibility,
    )

    manifest_name = "%s_manifest" % runtime_enabled_sdk_metadata_asset
    native.genrule(
        name = manifest_name,
        outs = [name + "/RuntimeEnabledSdkMetadata/AndroidManifest.xml"],
        cmd = """cat > $@ <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="{package}">
</manifest>
EOF
""".format(package = "%s.internalsdkmetadata" % app_package),
    )

    # Use the manifest in a normal android_library. This will later be added as a dependency to the
    # binary, so the runtime_enabled_sdk_metadata asset is present in the main app APK.
    runtime_enabled_sdk_metadata_lib_name = "%s_runtime_enabled_sdk_metadata_lib" % name
    _android_library(
        name = runtime_enabled_sdk_metadata_lib_name,
        assets = [":%s" % runtime_enabled_sdk_metadata_asset],
        assets_dir = assets_dir,
        manifest = ":%s" % manifest_name,
        testonly = testonly,
        tags = tags,
        transitive_configs = transitive_configs,
        visibility = visibility,
    )
    return ":%s" % runtime_enabled_sdk_metadata_lib_name

_android_binary_with_sandboxed_sdks = rule(
    attrs = dict(
        internal_android_binary = attr.label(
            providers = [
                [ApkInfo],
            ],
        ),
        debug_key = attr.label(
            allow_single_file = True,
            default = Label("//tools/android:debug_keystore"),
        ),
        sdk_bundles = attr.label_list(
            providers = [
                [AndroidSandboxedSdkBundleInfo],
            ],
        ),
        sdk_archives = attr.label_list(
            providers = [
                [AndroidArchivedSandboxedSdkInfo],
            ],
        ),
        use_compat_splits = attr.bool(default = False),
        _install_apks_script_template = attr.label(
            allow_single_file = True,
            default = ":install_apks_script.sh_template",
        ),
        _install_splits_script_template = attr.label(
            allow_single_file = True,
            default = ":install_splits_script.sh_template",
        ),
        _host_javabase = attr.label(
            cfg = "exec",
            default = Label("//tools/jdk:current_java_runtime"),
        ),
    ),
    executable = True,
    implementation = _android_binary_with_sandboxed_sdks_impl,
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
    ],
)

def android_binary_with_sandboxed_sdks_macro(
        _android_binary,
        _android_library,
        **attrs):
    """android_binary_with_sandboxed_sdks.

    Args:
      _android_binary: The android_binary rule to use.
      _android_library: The android_library rule to use.
      **attrs: android_binary attributes.
    """

    name = attrs.pop("name", None)
    fully_qualified_name = "//%s:%s" % (native.package_name(), name)
    if (not acls.in_android_binary_with_sandboxed_sdks_allowlist(fully_qualified_name)):
        fail("%s is not allowed to use the android_binary_with_sandboxed_sdks macro." %
             fully_qualified_name)

    app_package = _java.resolve_package_from_label(
        Label(fully_qualified_name),
        getattr(attrs, "custom_package", None),
    )
    sdk_bundles = attrs.pop("sdk_bundles", [])
    sdk_archives = attrs.pop("sdk_archives", [])
    debug_keystore = getattr(attrs, "debug_keystore", None)
    testonly = attrs.get("testonly", False)
    tags = attrs.get("tags", [])
    transitive_configs = attrs.get("transitive_configs", [])
    visibility = attrs.get("visibility", None)

    use_compat_splits = attrs.pop("use_compat_splits", False)

    deps = attrs.pop("deps", [])
    if use_compat_splits:
        deps.append(
            _get_extra_dependency_for_split_apks(
                name = name,
                app_package = app_package,
                sdk_archives = sdk_archives,
                sdk_bundles = sdk_bundles,
                testonly = testonly,
                tags = tags,
                transitive_configs = transitive_configs,
                visibility = visibility,
                _android_library = _android_library,
            ),
        )
    else:
        deps.append(
            _get_extra_dependency_for_sandboxed_apks(
                name = name,
                app_package = app_package,
                sdk_archives = sdk_archives,
                sdk_bundles = sdk_bundles,
                testonly = testonly,
                tags = tags,
                transitive_configs = transitive_configs,
                visibility = visibility,
                _android_library = _android_library,
            ),
        )

    # Generate the android_binary as normal, passing the extra flags.
    bin_label = Label("%s_app_bin" % fully_qualified_name)
    _android_binary(
        name = bin_label.name,
        deps = deps,
        **attrs
    )

    # This final rule will call Bundletool to generate the SDK APKs and provide the install script.
    _android_binary_with_sandboxed_sdks(
        name = name,
        sdk_bundles = sdk_bundles,
        sdk_archives = sdk_archives,
        debug_key = debug_keystore,
        use_compat_splits = use_compat_splits,
        internal_android_binary = bin_label,
        testonly = testonly,
        tags = tags,
        visibility = visibility,
    )
