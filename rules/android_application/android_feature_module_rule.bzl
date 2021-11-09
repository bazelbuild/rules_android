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

load(":attrs.bzl", "ANDROID_FEATURE_MODULE_ATTRS")
load("@rules_android//rules:java.bzl", _java = "java")
load(
    "@rules_android//rules:providers.bzl",
    "AndroidFeatureModuleInfo",
)
load("@rules_android//rules:acls.bzl", "acls")
load(
    "@rules_android//rules:utils.bzl",
    "get_android_toolchain",
)

def _impl(ctx):
    validation = ctx.actions.declare_file(ctx.label.name + "_validation")
    inputs = [ctx.attr.binary[ApkInfo].unsigned_apk]
    args = ctx.actions.args()
    args.add(validation.path)
    if ctx.file.manifest:
        args.add(ctx.file.manifest.path)
        inputs.append(ctx.file.manifest)
    else:
        args.add("")
    args.add(ctx.attr.binary[ApkInfo].unsigned_apk.path)
    args.add(ctx.configuration.coverage_enabled)
    args.add(ctx.fragments.android.desugar_java8_libs)
    args.add(ctx.attr.library.label)
    args.add(get_android_toolchain(ctx).xmllint_tool.files_to_run.executable)
    args.add(get_android_toolchain(ctx).unzip_tool.files_to_run.executable)

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
    )

    return [
        AndroidFeatureModuleInfo(
            binary = ctx.attr.binary,
            library = ctx.attr.library,
            title_id = ctx.attr.title_id,
            title_lib = ctx.attr.title_lib,
            feature_name = ctx.attr.feature_name,
            fused = ctx.attr.fused,
            manifest = ctx.file.manifest,
        ),
        OutputGroupInfo(_validation = depset([validation])),
    ]

android_feature_module = rule(
    attrs = ANDROID_FEATURE_MODULE_ATTRS,
    fragments = [
        "android",
        "java",
    ],
    implementation = _impl,
    provides = [AndroidFeatureModuleInfo],
    toolchains = ["@rules_android//toolchains/android:toolchain_type"],
    _skylark_testable = True,
)

def get_feature_module_paths(fqn):
    # Given a fqn to an android_feature_module, returns the absolute paths to
    # all implicitly generated targets
    return struct(
        binary = Label("%s_bin" % fqn),
        manifest_lib = Label("%s_AndroidManifest" % fqn),
        title_strings_xml = Label("%s_title_strings_xml" % fqn),
        title_lib = Label("%s_title_lib" % fqn),
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
    )

    # Create AndroidManifest.xml
    min_sdk_version = getattr(attrs, "min_sdk_version", "14") or "14"
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

    # Wrap any deps in an android_binary. Will be validated to ensure does not contain any dexes
    binary_attrs = {
        "name": targets.binary.name,
        "custom_package": getattr(attrs, "custom_package", None),
        "manifest": str(targets.manifest_lib),
        "deps": [attrs.library],
        "multidex": "native",
        "tags": tags,
        "transitive_configs": transitive_configs,
        "visibility": visibility,
        "feature_flags": getattr(attrs, "feature_flags", None),
        "$enable_manifest_merging": False,
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
        tags = tags,
        transitive_configs = transitive_configs,
        visibility = visibility,
        testonly = testonly,
    )
