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

load(":providers.bzl", "AndroidSandboxedSdkInfo")
load("//rules:android_binary.bzl", _android_binary = "android_binary")
load("//rules:java.bzl", _java = "java")

_ATTRS = dict(
    sdk_modules_config = attr.label(
        allow_single_file = [".pb.json"],
    ),
    internal_android_binary = attr.label(),
)

def _impl(ctx):
    return AndroidSandboxedSdkInfo(
        internal_apk_info = ctx.attr.internal_android_binary[ApkInfo],
        sdk_module_config = ctx.file.sdk_modules_config,
    )

_android_sandboxed_sdk = rule(
    attrs = _ATTRS,
    executable = False,
    implementation = _impl,
    provides = [
        AndroidSandboxedSdkInfo,
    ],
)

def android_sandboxed_sdk(
        name,
        sdk_modules_config,
        deps,
        min_sdk_version = 21,
        custom_package = None):
    """Rule to build an Android Sandboxed SDK.

    A sandboxed SDK is a collection of libraries that can run independently in the Privacy Sandbox
    or in a separate split APK of an app. See:
    https://developer.android.com/design-for-safety/privacy-sandbox.

    Args:
      name: Unique name of this target.
      sdk_modules_config: Module config for this SDK. For full definition see
        https://github.com/google/bundletool/blob/master/src/main/proto/sdk_modules_config.proto
      deps: Set of android libraries that make up this SDK.
      min_sdk_version: Min SDK version for the SDK.
      custom_package: Java package for which java sources will be generated. By default the package
        is inferred from the directory where the BUILD file containing the rule is. You can specify
        a different package but this is highly discouraged since it can introduce classpath
        conflicts with other libraries that will only be detected at runtime.
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

    bin_label = Label("%s_bin" % fully_qualified_name)
    _android_binary(
        name = bin_label.name,
        manifest = str(manifest_label),
        deps = deps,
    )
    _android_sandboxed_sdk(
        name = name,
        sdk_modules_config = sdk_modules_config,
        internal_android_binary = bin_label,
    )
