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

"""Bazel rule for defining an Android Sandboxed SDK."""

load(
    "//rules:common.bzl",
    _common = "common",
)
load("//rules:java.bzl", _java = "java")
load(
    "//rules:sandboxed_sdk_toolbox.bzl",
    _sandboxed_sdk_toolbox = "sandboxed_sdk_toolbox",
)
load(
    "//rules:utils.bzl",
    _get_android_toolchain = "get_android_toolchain",
)
load(":providers.bzl", "AndroidSandboxedSdkInfo")

_ATTRS = dict(
    sdk_modules_config = attr.label(
        allow_single_file = [".pb.json"],
    ),
    internal_android_binary = attr.label(),
    sdk_deploy_jar = attr.label(
        allow_single_file = [".jar"],
    ),
    _host_javabase = attr.label(
        cfg = "exec",
        default = Label("//tools/jdk:current_java_runtime"),
    ),
)

def _impl(ctx):
    sdk_api_descriptors = ctx.actions.declare_file(ctx.label.name + "_sdk_api_descriptors.jar")
    _sandboxed_sdk_toolbox.extract_api_descriptors(
        ctx,
        output = sdk_api_descriptors,
        sdk_deploy_jar = ctx.file.sdk_deploy_jar,
        sandboxed_sdk_toolbox = _get_android_toolchain(ctx).sandboxed_sdk_toolbox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )
    return [
        DefaultInfo(
            files = depset([sdk_api_descriptors]),
        ),
        AndroidSandboxedSdkInfo(
            internal_apk_info = ctx.attr.internal_android_binary[ApkInfo],
            sdk_module_config = ctx.file.sdk_modules_config,
            sdk_api_descriptors = sdk_api_descriptors,
        ),
    ]

_android_sandboxed_sdk = rule(
    attrs = _ATTRS,
    executable = False,
    implementation = _impl,
    provides = [
        AndroidSandboxedSdkInfo,
    ],
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
    ],
)

def android_sandboxed_sdk_macro(
        name,
        sdk_modules_config,
        deps,
        min_sdk_version = 21,
        visibility = None,
        testonly = None,
        tags = [],
        custom_package = None,
        android_binary = None):
    """Macro for an Android Sandboxed SDK.

    Args:
      name: Unique name of this target.
      sdk_modules_config: Module config for this SDK.
      deps: Set of android libraries that make up this SDK.
      min_sdk_version: Min SDK version for the SDK.
      visibility: A list of targets allowed to depend on this rule.
      testonly: Whether this library is only for testing.
      tags: A list of string tags passed to generated targets.
      custom_package: Java package for resources,
      android_binary: android_binary rule used to create the intermediate SDK APK.
    """
    fully_qualified_name = "//%s:%s" % (native.package_name(), name)
    package = _java.resolve_package_from_label(Label(fully_qualified_name), custom_package)

    manifest_label = Label("%s_gen_manifest" % fully_qualified_name)
    native.genrule(
        name = manifest_label.name,
        outs = [name + "/AndroidManifest.xml"],
        cmd = """cat > $@ <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="{package}">
    <uses-sdk android:minSdkVersion="{min_sdk_version}"/>
    <application />
</manifest>
EOF
""".format(package = package, min_sdk_version = min_sdk_version),
    )

    bin_fqn = "%s_bin" % fully_qualified_name
    bin_label = Label(bin_fqn)
    android_binary(
        name = bin_label.name,
        manifest = str(manifest_label),
        generate_art_profile = False,
        deps = deps,
        testonly = testonly,
        tags = tags,
    )

    sdk_deploy_jar = Label("%s_deploy.jar" % bin_fqn)
    _android_sandboxed_sdk(
        name = name,
        sdk_modules_config = sdk_modules_config,
        visibility = visibility,
        testonly = testonly,
        tags = tags,
        internal_android_binary = bin_label,
        sdk_deploy_jar = sdk_deploy_jar,
    )
