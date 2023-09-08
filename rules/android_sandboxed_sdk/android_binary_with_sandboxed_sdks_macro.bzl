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

load(":providers.bzl", "AndroidSandboxedSdkBundleInfo")
load("//rules:acls.bzl", "acls")
load("//rules:bundletool.bzl", _bundletool = "bundletool")
load("//rules:common.bzl", _common = "common")
load(
    "//rules:utils.bzl",
    _get_android_toolchain = "get_android_toolchain",
)
load("//rules:java.bzl", _java = "java")
load(
    "//rules:sandboxed_sdk_toolbox.bzl",
    _sandboxed_sdk_toolbox = "sandboxed_sdk_toolbox",
)

def _gen_sdk_dependencies_manifest_impl(ctx):
    manifest = ctx.actions.declare_file(ctx.label.name + "_sdk_dep_manifest.xml")
    module_configs = [
        bundle[AndroidSandboxedSdkBundleInfo].sdk_info.sdk_module_config
        for bundle in ctx.attr.sdk_bundles
    ]

    _sandboxed_sdk_toolbox.generate_sdk_dependencies_manifest(
        ctx,
        output = manifest,
        manifest_package = ctx.attr.package,
        sdk_module_configs = module_configs,
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

def _android_binary_with_sandboxed_sdks_impl(ctx):
    sdk_apks = []
    for idx, sdk_bundle_target in enumerate(ctx.attr.sdk_bundles):
        apk_out = ctx.actions.declare_file("%s/sdk_dep_apks/%s.apk" % (
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

    app_apk = ctx.attr.internal_android_binary[ApkInfo].signed_apk
    adb = _get_android_toolchain(ctx).adb.files_to_run.executable
    substitutions = {
        "%adb%": adb.short_path,
        "%app_apk%": app_apk.short_path,
        "%sdk_apks%": ",".join([apk.short_path for apk in sdk_apks]),
    }

    install_script = ctx.actions.declare_file("%s_install_script.sh" % ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file._install_script_template,
        output = install_script,
        substitutions = substitutions,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = install_script,
            files = depset([app_apk] + sdk_apks),
            runfiles = ctx.runfiles([
                adb,
                app_apk,
            ] + sdk_apks),
        ),
    ]

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
        _install_script_template = attr.label(
            allow_single_file = True,
            default = ":install_script.sh_template",
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

    sdk_bundles = attrs.pop("sdk_bundles", None)
    debug_keystore = getattr(attrs, "debug_keystore", None)

    bin_package = _java.resolve_package_from_label(
        Label(fully_qualified_name),
        getattr(attrs, "custom_package", None),
    )

    # Generate a manifest that lists all the SDK dependencies with <uses-sdk-library> tags.
    sdk_dependencies_manifest_name = "%s_sdk_dependencies_manifest" % name
    _gen_sdk_dependencies_manifest(
        name = sdk_dependencies_manifest_name,
        package = "%s.internalsdkdependencies" % bin_package,
        sdk_bundles = sdk_bundles,
    )

    # Use the manifest in a normal android_library. This will later be added as a dependency to the
    # binary, so the manifest is merged with the app's.
    sdk_dependencies_lib_name = "%s_sdk_dependencies_lib" % name
    _android_library(
        name = sdk_dependencies_lib_name,
        exports_manifest = 1,
        manifest = ":%s" % sdk_dependencies_manifest_name,
    )
    deps = attrs.pop("deps", [])
    deps.append(":%s" % sdk_dependencies_lib_name)

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
        debug_key = debug_keystore,
        internal_android_binary = bin_label,
    )
