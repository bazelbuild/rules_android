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
"""android_feature_module rule."""

load(
    "//providers:providers.bzl",
    "AndroidFeatureModuleInfo",
    "AndroidIdeInfo",
    "ApkInfo",
    "ResourcesNodeInfo",
    "StarlarkAndroidResourcesInfo",
)
load("//rules:acls.bzl", "acls")
load("//rules:java.bzl", _java = "java")
load("//rules:min_sdk_version.bzl", _min_sdk_version = "min_sdk_version")
load(
    "//rules:utils.bzl",
    "get_android_toolchain",
    "utils",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":attrs.bzl", "ANDROID_FEATURE_MODULE_ATTRS")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_java//java/common:proguard_spec_info.bzl", "ProguardSpecInfo")

visibility(PROJECT_VISIBILITY)

def _impl(ctx):
    validation = ctx.actions.declare_file(ctx.label.name + "_validation")
    if ctx.attr.binary[AndroidIdeInfo].native_libs and ctx.attr.is_asset_pack:
        fail("Feature module %s is marked as an asset pack but contains native libraries" % ctx.label.name)
    inputs = [ctx.attr.binary[ApkInfo].unsigned_apk]
    args = ctx.actions.args()
    args.add(validation.path)
    if ctx.file.manifest:
        args.add(ctx.file.manifest.path)
        inputs.append(ctx.file.manifest)
    else:
        args.add("")
    args.add(ctx.attr.binary[ApkInfo].unsigned_apk.path)
    args.add(utils.dedupe_split_attr(ctx.split_attr.library).label)
    args.add(get_android_toolchain(ctx).xmllint_tool.files_to_run.executable)
    args.add(get_android_toolchain(ctx).unzip_tool.files_to_run.executable)
    args.add(ctx.attr.is_asset_pack)

    ctx.actions.run(
        executable = ctx.executable._feature_module_validation_script,
        inputs = inputs,
        outputs = [validation],
        arguments = [args],
        tools = [
            get_android_toolchain(ctx).xmllint_tool.files_to_run.executable,
            get_android_toolchain(ctx).unzip_tool.files_to_run.executable,
        ],
        mnemonic = "ValidateFeatureModule",
        progress_message = "Validating feature module %s" % str(ctx.label),
        toolchain = None,
    )

    proguard_provider = []
    if ctx.attr.proguard_specs:
        proguard_provider = [
            ProguardSpecInfo(depset(ctx.files.proguard_specs))
        ]

    return [
        AndroidFeatureModuleInfo(
            binary = ctx.attr.binary,
            library = utils.dedupe_split_attr(ctx.split_attr.library),
            title_id = ctx.attr.title_id,
            title_lib = ctx.attr.title_lib,
            library_resources_only_lib = ctx.attr.library_resources_only_lib,
            feature_name = ctx.attr.feature_name,
            fused = ctx.attr.fused,
            manifest = ctx.file.manifest,
            is_asset_pack = ctx.attr.is_asset_pack,
        ),
        OutputGroupInfo(_validation = depset([validation])),
    ] + proguard_provider

android_feature_module = rule(
    attrs = ANDROID_FEATURE_MODULE_ATTRS,
    fragments = [
        "android",
        "bazel_android",  # NOTE: Only exists for Bazel
        "java",
    ],
    implementation = _impl,
    provides = [AndroidFeatureModuleInfo],
    toolchains = ["//toolchains/android:toolchain_type"],
    _skylark_testable = True,
)

def get_feature_module_paths(fqn):
    # Given a fqn to an android_feature_module, returns the absolute paths to
    # all implicitly generated targets
    return struct(
        binary = native.package_relative_label("%s_bin" % fqn),
        manifest_lib = native.package_relative_label("%s_AndroidManifest" % fqn),
        title_strings_xml = native.package_relative_label("%s_title_strings_xml" % fqn),
        title_lib = native.package_relative_label("%s_title_lib" % fqn),
        library_resources_only_lib = native.package_relative_label("%s_resources_only_lib" % fqn),
    )

def android_feature_module_macro(_android_binary, _android_library, **attrs):
    """android_feature_module_macro.

    Args:
      _android_binary: The android_binary rule to use.
      _android_library: The android_library rule to use.
      **attrs: android_feature_module attributes.
    """

    # Enable dot syntax
    attrs = struct(**attrs)
    fqn = "//%s:%s" % (native.package_name(), attrs.name)

    required_attrs = ["name", "library", "title"]
    if not acls.in_android_feature_splits_dogfood(fqn):
        required_attrs.append("manifest")

    # Check for required macro attributes
    for attr in required_attrs:
        if not getattr(attrs, attr, None):
            fail("%s missing required attr <%s>" % (fqn, attr))

    if hasattr(attrs, "fused") and hasattr(attrs, "manifest"):
        fail("%s cannot specify <fused> and <manifest>. Prefer <manifest>")

    targets = get_feature_module_paths(fqn)

    tags = getattr(attrs, "tags", [])
    tags += ["has_proguard_specs"]

    transitive_configs = getattr(attrs, "transitive_configs", [])
    visibility = getattr(attrs, "visibility", None)
    testonly = getattr(attrs, "testonly", None)

    # Create strings.xml containing split title
    title_id = "split_" + str(hash(fqn)).replace("-", "N")
    native.genrule(
        name = targets.title_strings_xml.name,
        outs = [attrs.name + "/res/values/strings.xml"],
        cmd = """cat > $@ <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2"
xmlns:tools="http://schemas.android.com/tools"
tools:keep="@string/{title_id}">
    <string name="{title_id}">{title}</string>
</resources>
EOF
""".format(title = attrs.title, title_id = title_id),
    visibility = ["//visibility:public"],
    )

    # Create AndroidManifest.xml
    min_sdk_version = getattr(attrs, "min_sdk_version", _min_sdk_version.DEPOT_FLOOR) or _min_sdk_version.DEPOT_FLOOR
    package = _java.resolve_package_from_label(Label(fqn), getattr(attrs, "custom_package", None))
    native.genrule(
        name = targets.manifest_lib.name,
        outs = [attrs.name + "/AndroidManifest.xml"],
        cmd = """cat > $@ <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="{package}">
    <uses-sdk
      android:minSdkVersion="{min_sdk_version}"/>
</manifest>
EOF
""".format(package = package, min_sdk_version = min_sdk_version),
    )

    # Resource processing requires an android_library target
    _android_library(
        name = targets.title_lib.name,
        custom_package = getattr(attrs, "custom_package", None),
        manifest = str(targets.manifest_lib),
        resource_files = [str(targets.title_strings_xml)],
        tags = tags,
        transitive_configs = transitive_configs,
        visibility = visibility,
        testonly = testonly,
    )

    # Create a resource-only android library so that base module
    # includes android resources of feature modules, similarly to Buck.
    resource_only_lib_internal_name = targets.library_resources_only_lib.name + "_internal"
    android_resources_only(
        name = resource_only_lib_internal_name,
        deps = [attrs.library],
    )
    _android_library(
        name = targets.library_resources_only_lib.name,
        exports = [":" + resource_only_lib_internal_name],
        visibility = visibility,
    )

    # Wrap any deps in an android_binary. Will be validated to ensure does not contain any dexes
    binary_attrs = {
        "name": targets.binary.name,
        "custom_package": getattr(attrs, "custom_package", None),
        "manifest": str(targets.manifest_lib),
        "deps": [attrs.library],
        "tags": tags,
        "transitive_configs": transitive_configs,
        "visibility": visibility,
        "feature_flags": getattr(attrs, "feature_flags", None),
        "$enable_manifest_merging": True,
        "testonly": testonly,
    }
    _android_binary(**binary_attrs)

    android_feature_module(
        name = attrs.name,
        library = attrs.library,
        binary = str(targets.binary),
        title_id = title_id,
        title_lib = str(targets.title_lib),
        feature_name = getattr(attrs, "feature_name", attrs.name),
        fused = getattr(attrs, "fused", True),
        manifest = getattr(attrs, "manifest", None),
        proguard_specs = getattr(attrs, "proguard_specs", []),
        tags = tags,
        transitive_configs = transitive_configs,
        visibility = visibility,
        testonly = testonly,
        is_asset_pack = getattr(attrs, "is_asset_pack", False),
    )

# Dedicated rules to implement a resource-only android library from all transitive deps.
def _android_resources_only_impl(ctx):
    direct_resources_nodes = []
    direct_compiled_resources = []
    transitive_compiled_resources = []
    transitive_r_txts = []
    transitive_resource_files = []
    packages_to_r_txts_depset = dict()
    transitive_resource_apks = []

    for dep in ctx.attr.deps:
        if StarlarkAndroidResourcesInfo in dep:
            info = dep[StarlarkAndroidResourcesInfo]
            for resources_node in info.direct_resources_nodes.to_list():
                filtered_resources_node = ResourcesNodeInfo(
                    label = resources_node.label,
                    assets = depset(),
                    assets_dir = None,
                    assets_symbols = None,
                    compiled_assets = None,
                    resource_apks = resources_node.resource_apks,
                    resource_files = resources_node.resource_files,
                    compiled_resources = resources_node.compiled_resources,
                    r_txt = resources_node.r_txt,
                    manifest = resources_node.manifest,
                    exports_manifest = False,
                )
                direct_resources_nodes.append(filtered_resources_node)
            direct_compiled_resources.append(info.direct_compiled_resources)
            transitive_compiled_resources.append(info.transitive_compiled_resources)
            transitive_r_txts.append(info.transitive_r_txts)
            transitive_resource_files.append(info.transitive_resource_files)
            transitive_resource_apks.append(info.transitive_resource_apks)
            for pkg, r_txts in info.packages_to_r_txts.items():
                packages_to_r_txts_depset.setdefault(pkg, []).append(r_txts)

    packages_to_r_txts = dict()
    for pkg, depsets in packages_to_r_txts_depset.items():
        packages_to_r_txts[pkg] = depset(transitive = depsets)

    provider = StarlarkAndroidResourcesInfo(
        direct_resources_nodes = depset(direct_resources_nodes),
        transitive_resources_nodes = depset(),
        direct_compiled_resources = depset(transitive=direct_compiled_resources),
        transitive_compiled_resources = depset(transitive=transitive_compiled_resources),
        transitive_r_txts = depset(transitive=transitive_r_txts),
        transitive_resource_files = depset(transitive=transitive_resource_files),
        packages_to_r_txts = packages_to_r_txts,
        transitive_resource_apks = depset(transitive=transitive_resource_apks),
        transitive_assets = depset(),
        transitive_assets_symbols = depset(),
        transitive_compiled_assets = depset(),
        transitive_manifests = depset(),
    )

    return [provider, CcInfo()]

android_resources_only = rule(
    implementation = _android_resources_only_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "Android libraries containing both resources and Java code",
            providers = [StarlarkAndroidResourcesInfo],  # Ensure only android_library targets are allowed
        ),
    },
)
