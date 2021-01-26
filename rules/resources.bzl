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

"""Bazel Android Resources."""

load(":attrs.bzl", _attrs = "attrs")
load(":busybox.bzl", _busybox = "busybox")
load(":common.bzl", _common = "common")
load(":java.bzl", _java = "java")
load(":path.bzl", _path = "path")
load(
    ":providers.bzl",
    "ResourcesNodeInfo",
    "StarlarkAndroidResourcesInfo",
)
load(
    ":utils.bzl",
    "utils",
    _compilation_mode = "compilation_mode",
    _log = "log",
)

_RESOURCE_FOLDER_TYPES = [
    "anim",
    "animator",
    "color",
    "drawable",
    "font",
    "interpolator",
    "layout",
    "menu",
    "mipmap",
    "navigation",
    "values",
    "xml",
    "raw",
    "transition",
]

_RESOURCE_QUALIFIER_SEP = "-"

_MANIFEST_MISSING_ERROR = (
    "In target %s, manifest attribute is required when resource_files or " +
    "assets are defined."
)

_ASSET_DEFINITION_ERROR = (
    "In target %s, the assets and assets_dir attributes should be either " +
    "both empty or non-empty."
)

_JAVA_PACKAGE_MISSING_ERROR = (
    "In target %s, a java package is required when stamping " +
    "the manifest."
)

_INCORRECT_RESOURCE_LAYOUT_ERROR = (
    "'%s' is not in the expected resource directory structure of " +
    "<resource directory>/{%s}/<file>" % (",").join(_RESOURCE_FOLDER_TYPES)
)

# Keys for manifest_values
_VERSION_NAME = "versionName"
_VERSION_CODE = "versionCode"

# Resources context attributes.
_ASSETS_PROVIDER = "assets_provider"
_DEFINES_RESOURCES = "defines_resources"
_DIRECT_ANDROID_RESOURCES = "direct_android_resources"
_MERGED_MANIFEST = "merged_manifest"
_PROVIDERS = "providers"
_R_JAVA = "r_java"
_RESOURCES_APK = "resources_apk"
_VALIDATION_RESULTS = "validation_results"
_VALIDATION_OUTPUTS = "validation_outputs"
_RESOURCES_PROVIDER = "resources_provider"
_STARLARK_PROCESSED_MANIFEST = "starlark_processed_manifest"
_STARLARK_R_TXT = "starlark_r_txt"
_STARLARK_PROCESSED_RESOURCES = "starlark_processed_resources"

_ResourcesProcessContextInfo = provider(
    "Resources context object",
    fields = {
        _DEFINES_RESOURCES: "If local resources were defined.",
        _DIRECT_ANDROID_RESOURCES: "Direct android resources.",
        _MERGED_MANIFEST: "Merged manifest.",
        _PROVIDERS: "The list of all providers to propagate.",
        _R_JAVA: "JavaInfo for R.jar.",
        _RESOURCES_APK: "ResourcesApk.",
        _VALIDATION_RESULTS: "List of validation results.",
        _VALIDATION_OUTPUTS: "List of outputs given to OutputGroupInfo _validation group",

        # TODO(djwhang): The android_library aar generation requires direct
        # access to providers. Remove once aar is its own rule.
        _ASSETS_PROVIDER: "AndroidAssetsInfo provider.",
        _RESOURCES_PROVIDER: "AndroidResourcesInfo provider.",
        _STARLARK_PROCESSED_MANIFEST: "The processed manifest from the starlark resource processing pipeline.",
        _STARLARK_R_TXT: "The R.txt from the starlark resource processing pipeline.",
        _STARLARK_PROCESSED_RESOURCES: "The processed resources from the starlark processing pipeline.",
    },
)

# Packaged resources context attributes.
_PACKAGED_FINAL_MANIFEST = "processed_manifest"
_PACKAGED_RESOURCE_APK = "resources_apk"
_PACKAGED_CLASS_JAR = "class_jar"
_PACKAGED_VALIDATION_RESULT = "validation_result"

_ResourcesPackageContextInfo = provider(
    "Packaged resources context object",
    fields = {
        _PACKAGED_FINAL_MANIFEST: "Final processed manifest.",
        _PACKAGED_RESOURCE_APK: "ResourceApk.",
        _PACKAGED_CLASS_JAR: "R class jar.",
        _PACKAGED_VALIDATION_RESULT: "Validation result.",
        _R_JAVA: "JavaInfo for R.jar",
        _PROVIDERS: "The list of all providers to propagate.",
    },
)

def _generate_dummy_manifest(
        ctx,
        out_manifest = None,
        java_package = None,
        min_sdk_version = None):
    content = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="%s">""" % java_package

    if min_sdk_version:
        content = content + """
    <uses-sdk android:minSdkVersion="%s" />""" % min_sdk_version

    content = content + """
    <application>
    </application>
</manifest>"""

    ctx.actions.write(
        output = out_manifest,
        content = content,
    )

def _add_g3itr(
        ctx,
        manifest = None,
        out_manifest = None,
        xsltproc = None,
        instrument_xslt = None):
    """Adds Google3InstrumentationTestRunner instrumentation element to the manifest.

    Element is only added if the manifest contains an instrumentation element with
    name "android.test.InstrumentationTestRunner". The added element's name attr is
    "com.google.android.apps.common.testing.testrunner.Google3InstrumentationTestRunner".

    Args:
      ctx: The context.
      manifest: File. The AndroidManifest.xml file.
      out_manifest: File. The transformed AndroidManifest.xml.
      xsltproc: FilesToRunProvider. The xsltproc executable or
        FilesToRunProvider.
      instrument_xslt: File. The add_g3itr.xslt file describing the xslt
        transformation to apply.
    """
    args = ctx.actions.args()
    args.add("--nonet")
    args.add("--novalid")
    args.add("-o", out_manifest)
    args.add(instrument_xslt)
    args.add(manifest)

    ctx.actions.run(
        executable = xsltproc,
        arguments = [args],
        inputs = [manifest, instrument_xslt],
        outputs = [out_manifest],
        mnemonic = "AddG3ITRStarlark",
        progress_message = "Adding G3ITR to test manifest for %s" % ctx.label,
    )

def _get_legacy_mergee_manifests(resources_infos):
    all_dependencies = depset(
        transitive = [
            ri.direct_android_resources
            for ri in resources_infos
        ] + [
            ri.transitive_android_resources
            for ri in resources_infos
        ],
    )

    mergee_manifests = []
    for dep in all_dependencies.to_list():
        if dep.to_provider.manifest.exports_manifest:
            mergee_manifests.append(dep.to_provider.manifest.manifest)

    return depset(mergee_manifests)

def _legacy_mergee_manifest(manifest):
    sort_key = manifest.short_path + "#"
    return sort_key + "--mergee=" + manifest.path

def _legacy_merge_manifests(
        ctx,
        out_merged_manifest = None,
        manifest = None,
        mergee_manifests = None,
        legacy_merger = None):
    """Merges manifests with the legacy manifest merger."

    This should not be called with empty mergee_manifests.

    Args:
      ctx: The context.
      out_merged_manifest: File. The merged AndroidManifest.xml.
      manifest: File. The AndroidManifest.xml.
      mergee_manifests: A sequence of Files. All transitive manifests to be merged.
      legacy_merger: A FilesToRunProvider. The legacy manifest merger executable.
    """
    args = ctx.actions.args()
    args.use_param_file("%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add("--merger=%s" % manifest.path)
    args.add("--exclude_permission=all")
    args.add("--output=%s" % out_merged_manifest.path)

    manifest_params = ctx.actions.declare_file(ctx.label.name + "/legacy_merger.params")
    manifest_args = ctx.actions.args()
    manifest_args.use_param_file("%s", use_always = True)
    manifest_args.set_param_file_format("multiline")
    manifest_args.add_joined(mergee_manifests, map_each = _legacy_mergee_manifest, join_with = "\n")
    ctx.actions.run_shell(
        command = """
# Sorts the mergee manifests by path and combines with other busybox args.
set -e
SORTED=`sort $1 | sed 's/^.*#//'`
cat $2 > $3
echo "$SORTED" >> $3
""",
        arguments = [manifest_args, args, manifest_params.path],
        outputs = [manifest_params],
    )
    args = ctx.actions.args()
    args.add(manifest_params, format = "--flagfile=%s")

    ctx.actions.run(
        executable = legacy_merger,
        arguments = [args],
        inputs = depset([manifest, manifest_params], transitive = [mergee_manifests]),
        outputs = [out_merged_manifest],
        mnemonic = "StarlarkLegacyAndroidManifestMerger",
        progress_message = "Merging Android Manifests",
    )

def _make_databinding_outputs(
        ctx,
        resource_files):
    """Helper method to create arguments for the process_databinding busybox tool.

    Declares databinding-processed resource files that are generated by the
    PROCESS_DATABINDING busybox tool, which must be declared underneath an output
    resources directory and namespaced by their paths. The busybox takes the
    output directory exec path and generates the underlying resource files.

    Args:
      ctx: The context.
      resource_files: List of Files. The android resource files to be processed by
        _process_databinding.

    Returns:
      A tuple containing the list of declared databinding processed resource files and the
        output resource directory path expected by the busybox. The path is a full path.
    """

    # TODO(b/160907203): Clean up databinding_rel_path. We capitalize "Databinding" here to avoid
    # conflicting with native artifact file names. This is changed back to "databinding" during
    # process_starlark so that compiled resources exactly match those of the native resource
    # processing pipeline. Even a single character mismatch in the file names causes selected
    # resources to differ in the final APK.
    databinding_rel_path = _path.join(["Databinding-processed-resources", ctx.label.name])
    databinding_processed_resources = [
        ctx.actions.declare_file(_path.join([databinding_rel_path, f.path]))
        for f in resource_files
    ]
    databinding_resources_dirname = _path.join([
        ctx.bin_dir.path,
        ctx.label.package,
        databinding_rel_path,
    ])
    return databinding_processed_resources, databinding_resources_dirname

def _fix_databinding_compiled_resources(
        ctx,
        out_compiled_resources = None,
        compiled_resources = None,
        zip_tool = None):
    """Fix compiled resources to match those produced by the native pipeline.

    Changes "Databinding" to "databinding" in each compiled resource .flat file name and header.

    Args:
      ctx: The context.
      out_compiled_resources: File. The modified compiled_resources output.
      compiled_resources: File. The compiled_resources zip.
    """
    ctx.actions.run_shell(
        outputs = [out_compiled_resources],
        inputs = [compiled_resources],
        tools = [zip_tool],
        arguments = [compiled_resources.path, out_compiled_resources.path, zip_tool.executable.path],
        command = """#!/bin/bash
set -e

IN_DIR=$(mktemp -d)
OUT_DIR=$(mktemp -d)
CUR_PWD=$(pwd)

if zipinfo -t "$1"; then
    ORDERED_LIST=`(unzip -l "$1" | sed -e '1,3d' | head -n -2 | tr -s " " | cut -d " " -f5)`

    unzip -q "$1" -d "$IN_DIR"

    # Iterate through the ordered list, change "Databinding" to "databinding" in the file header
    # and file name and zip the files with the right comment
    for FILE in $ORDERED_LIST; do
        cd "$IN_DIR"
        if [ -f "$FILE" ]; then
            sed -i 's/Databinding\\-processed\\-resources/databinding\\-processed\\-resources/g' "$FILE"
            NEW_NAME=`echo "$FILE" | sed 's/Databinding\\-processed\\-resources/databinding\\-processed\\-resources/g' | sed 's#'"$IN_DIR"'/##g'`
            mkdir -p `dirname "$OUT_DIR/$NEW_NAME"` && touch "$OUT_DIR/$NEW_NAME"
            cp -p "$FILE" "$OUT_DIR/$NEW_NAME"

            PATH_SEGMENTS=(`echo ${FILE} | tr '/' ' '`)
            BASE_PATH_SEGMENT="${PATH_SEGMENTS[0]}"
                COMMENT=
            if [ "${BASE_PATH_SEGMENT}" == "generated" ]; then
                COMMENT="generated"
            elif [ "${BASE_PATH_SEGMENT}" == "default" ]; then
                COMMENT="default"
            fi

            cd "$OUT_DIR"
            "$CUR_PWD/$3" -jt -X -0 -q -r -c "$CUR_PWD/$2" $NEW_NAME <<EOM
${COMMENT}
EOM
        fi
    done

    cd "$CUR_PWD"
    touch -r "$1" "$2"
else
    cp -p "$1" "$2"
fi
        """,
    )

def _is_resource_shrinking_enabled(
        shrink_resources,
        use_android_resource_shrinking):
    if shrink_resources == _attrs.tristate.auto:
        return use_android_resource_shrinking
    return shrink_resources == _attrs.tristate.yes

def _should_shrink_resource_cycles(
        use_android_resource_cycle_shrinking,
        resource_shrinking_enabled):
    if use_android_resource_cycle_shrinking and not resource_shrinking_enabled:
        fail("resource cycle shrinking can only be enabled when resource shrinking is enabled")
    return use_android_resource_cycle_shrinking

def _filter_multi_cpu_configuration_targets(
        targets):
    """Filter out duplicate split-configured targets.

    This method simulates logic in the native rule where if a label_list attribute has
    split-configuration but is requested in target mode, only targets from the first architecture
    are returned. Without this filtering there are duplicate targets if multiple CPU configurations
    are specified on the command line. This is the case with deps in the packaging step of
    android_binary.

    Args:
      targets: A list of Target objects.

    Returns:
      A list of Target objects with duplicates removed.
    """
    seen_labels = {}
    filtered_targets = []
    for t in targets:
        if t.label in seen_labels:
            continue
        seen_labels[t.label] = True
        filtered_targets.append(t)
    return filtered_targets

def _package(
        ctx,
        assets = [],
        assets_dir = None,
        deps = [],
        manifest = None,
        manifest_values = None,
        instruments = None,
        resource_configs = None,
        densities = [],
        resource_files = [],
        nocompress_extensions = [],
        java_package = None,
        compilation_mode = _compilation_mode.FASTBUILD,
        shrink_resources = None,
        use_android_resource_shrinking = None,
        use_android_resource_cycle_shrinking = None,
        use_legacy_manifest_merger = False,
        should_throw_on_conflict = True,
        enable_data_binding = False,
        enable_manifest_merging = True,
        aapt = None,
        android_jar = None,
        legacy_merger = None,
        xsltproc = None,
        instrument_xslt = None,
        busybox = None,
        host_javabase = None):
    """Package resources for top-level rules.

    Args:
      ctx: The context.
      assets: sequence of Files. A list of assets to be packaged. All files be
        under the assets_dir directory in the corresponding package.
      assets_dir: String. A string giving the path to the files in assets. The
        pair assets and assets_dir describe packaged assets and either both
        parameters should be provided or none of them.
      deps: sequence of Targets. The list of other libraries targets to link
        against.
      manifest: File. The input top-level AndroidManifest.xml.
      manifest_values: String dictionary. Manifest values to substitute.
      instruments: Optional target. The value of the "instruments" attr if set.
      resource_configs: sequence of Strings. A list of resource_configuration_filters
        to apply.
      densities: sequence of Strings. A list of densities to filter for when building
        the apk.
      resource_files: sequence of Files. A list of Android resource files
        to be processed.
      nocompress_extensions: sequence of Strings. File extension to leave uncompressed
        in the apk.
      java_package: String. Java package for which java sources will be
        generated. By default the package is inferred from the directory where
        the BUILD file containing the rule is.
      compilation_mode: String. A string that represents compilation mode. The
        list of expected values are as follows: dbg, fastbuild, opt.
      shrink_resources: Tristate. Whether resource shrinking is enabled by the rule.
      use_android_resource_shrinking: Bool. Flag that controls the default value for
        shrink_resources if the tristate value is auto (-1).
      use_android_resource_cycle_shrinking: Bool. Flag that enables more shrinking of
        code and resources by instructing AAPT2 to emit conditional Proguard keep rules.
      use_legacy_manifest_merger: A boolean. Whether to use the legacy manifest merger
      instead of the android manifest merger.
      should_throw_on_conflict: A boolean. Determines whether an error should be thrown
        when a resource conflict occurs.
      enable_data_binding: boolean. If true, processesing the data binding
        expressions in layout resources included through the resource_files
        parameter is enabled. Without this setting, data binding expressions
        produce build failures.
      enable_manifest_merging: boolean. If true, manifest merging will be performed.
      aapt: FilesToRunProvider. The aapt executable or FilesToRunProvider.
      android_jar: File. The Android jar.
      legacy_merger: FilesToRunProvider. The legacy manifest merger executable.
      xsltproc: FilesToRunProvider. The xsltproc executable or
        FilesToRunProvider.
      instrument_xslt: File. The add_g3itr.xslt file describing the xslt
        transformation to apply.
      busybox: FilesToRunProvider. The ResourceBusyBox executable or
        FilesToRunprovider
      host_javabase: A Target. The host javabase.

    Returns:
      A ResourcesPackageContextInfo containing packaged resource artifacts and
        providers.
    """
    _validate_resources(resource_files)

    # Filtering is necessary if a build is requested with multiple CPU configurations.
    deps = _filter_multi_cpu_configuration_targets(deps)

    packaged_resources_ctx = {
        _PROVIDERS: [],
    }

    g3itr_manifest = manifest

    if xsltproc or instrument_xslt:
        g3itr_manifest = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + "add_g3itr/AndroidManifest.xml",
        )
        _add_g3itr(
            ctx,
            out_manifest = g3itr_manifest,
            manifest = manifest,
            xsltproc = xsltproc,
            instrument_xslt = instrument_xslt,
        )

    direct_resources_nodes = []
    transitive_resources_nodes = []
    transitive_assets = []
    transitive_assets_symbols = []
    transitive_compiled_assets = []
    transitive_resource_files = []
    transitive_compiled_resources = []
    transitive_manifests = []
    transitive_r_txts = []
    for dep in utils.collect_providers(StarlarkAndroidResourcesInfo, deps):
        direct_resources_nodes.append(dep.direct_resources_nodes)
        transitive_resources_nodes.append(dep.transitive_resources_nodes)
        transitive_assets.append(dep.transitive_assets)
        transitive_assets_symbols.append(dep.transitive_assets_symbols)
        transitive_compiled_assets.append(dep.transitive_compiled_assets)
        transitive_resource_files.append(dep.transitive_resource_files)
        transitive_compiled_resources.append(dep.transitive_compiled_resources)
        transitive_manifests.append(dep.transitive_manifests)
        transitive_r_txts.append(dep.transitive_r_txts)

    mergee_manifests = depset([
        node_info.manifest
        for node_info in depset(transitive = transitive_resources_nodes + direct_resources_nodes).to_list()
        if node_info.exports_manifest
    ])

    # TODO(b/156763506): Add analysis tests to verify logic around when manifest merging is configured.
    # TODO(b/154153771): Run the android merger if mergee_manifests or manifest values are present.
    merged_manifest = g3itr_manifest
    if enable_manifest_merging and (manifest_values or mergee_manifests):
        if use_legacy_manifest_merger:
            # Legacy manifest merger only runs if mergee manifests are present
            if mergee_manifests:
                merged_manifest = ctx.actions.declare_file(
                    "_migrated/_merged/" + ctx.label.name + "/AndroidManifest.xml",
                )
                _legacy_merge_manifests(
                    ctx,
                    out_merged_manifest = merged_manifest,
                    manifest = g3itr_manifest,
                    mergee_manifests = mergee_manifests,
                    legacy_merger = legacy_merger,
                )
        else:
            merged_manifest = ctx.actions.declare_file(
                "_migrated/_merged/" + ctx.label.name + "/AndroidManifest.xml",
            )
            _busybox.merge_manifests(
                ctx,
                out_file = merged_manifest,
                out_log_file = ctx.actions.declare_file(
                    "_migrated/_merged/" + ctx.label.name + "/manifest_merger_log.txt",
                ),
                manifest = g3itr_manifest,
                mergee_manifests = mergee_manifests,
                manifest_values = manifest_values,
                merge_type = "APPLICATION",
                java_package = java_package,
                busybox = busybox,
                host_javabase = host_javabase,
            )

    processed_resources = resource_files
    databinding_info = None
    if enable_data_binding:
        databinding_info = ctx.actions.declare_file("_migrated/databinding/" + ctx.label.name + "/layout-info.zip")
        processed_resources, resources_dirname = _make_databinding_outputs(
            ctx,
            resource_files,
        )
        _busybox.process_databinding(
            ctx,
            out_databinding_info = databinding_info,
            out_databinding_processed_resources = processed_resources,
            databinding_resources_dirname = resources_dirname,
            resource_files = resource_files,
            java_package = java_package,
            busybox = busybox,
            host_javabase = host_javabase,
        )

    resource_apk = ctx.actions.declare_file(ctx.label.name + "_migrated/.ap_")
    r_java = ctx.actions.declare_file("_migrated/" + ctx.label.name + ".srcjar")
    r_txt = ctx.actions.declare_file(ctx.label.name + "_migrated/_symbols/R.txt")
    processed_manifest = ctx.actions.declare_file(ctx.label.name + "_migrated/_processed_manifest/AndroidManifest.xml")
    proguard_cfg = ctx.actions.declare_file(
        "_migrated/proguard/%s/_%s_proguard.cfg" % (ctx.label.name, ctx.label.name),
    )
    main_dex_proguard_cfg = ctx.actions.declare_file(
        "_migrated/proguard/%s/main_dex_%s_proguard.cfg" %
        (ctx.label.name, ctx.label.name),
    )
    resource_files_zip = ctx.actions.declare_file(
        "_migrated/" + ctx.label.name + "_files/resource_files.zip",
    )
    _busybox.package(
        ctx,
        out_file = resource_apk,
        out_r_src_jar = r_java,
        out_r_txt = r_txt,
        out_symbols = ctx.actions.declare_file("_migrated/" + ctx.label.name + "_symbols/merged.bin"),
        out_manifest = processed_manifest,
        out_proguard_cfg = proguard_cfg,
        out_main_dex_proguard_cfg = main_dex_proguard_cfg,
        out_resource_files_zip = resource_files_zip,
        application_id = manifest_values.get("applicationId", None),
        manifest = merged_manifest,
        assets = assets,
        assets_dir = assets_dir,
        resource_files = processed_resources,
        direct_resources_nodes =
            depset(transitive = direct_resources_nodes, order = "preorder"),
        transitive_resources_nodes =
            depset(transitive = transitive_resources_nodes, order = "preorder"),
        transitive_assets = transitive_assets,
        transitive_compiled_assets = transitive_compiled_assets,
        transitive_resource_files = transitive_resource_files,
        transitive_compiled_resources = transitive_compiled_resources,
        transitive_manifests = transitive_manifests,
        transitive_r_txts = transitive_r_txts,
        resource_configs = resource_configs,
        densities = densities,
        nocompress_extensions = nocompress_extensions,
        java_package = java_package,
        version_name = manifest_values[_VERSION_NAME] if _VERSION_NAME in manifest_values else None,
        version_code = manifest_values[_VERSION_CODE] if _VERSION_CODE in manifest_values else None,
        android_jar = android_jar,
        aapt = aapt,
        busybox = busybox,
        host_javabase = host_javabase,
        debug = compilation_mode != _compilation_mode.OPT,
        should_throw_on_conflict = should_throw_on_conflict,
    )
    packaged_resources_ctx[_PACKAGED_FINAL_MANIFEST] = processed_manifest
    packaged_resources_ctx[_PACKAGED_RESOURCE_APK] = resource_apk
    packaged_resources_ctx[_PACKAGED_VALIDATION_RESULT] = resource_files_zip

    resource_shrinking_enabled = _is_resource_shrinking_enabled(
        shrink_resources,
        use_android_resource_shrinking,
    )
    shrink_resource_cycles = _should_shrink_resource_cycles(
        use_android_resource_cycle_shrinking,
        resource_shrinking_enabled,
    )

    # Fix class jar name because some tests depend on {label_name}_resources.jar being the suffix of
    # the path, with _RESOURCES_DO_NOT_USE removed from the label name.
    _RESOURCES_SUFFIX = "_RESOURCES_DO_NOT_USE"
    class_jar_name = ctx.label.name + "_migrated/_resources.jar"
    if ctx.label.name.endswith(_RESOURCES_SUFFIX):
        label_name = ctx.label.name[:-len(_RESOURCES_SUFFIX)]
        class_jar_name = ctx.label.name + "_migrated/" + label_name + "_resources.jar"

    class_jar = ctx.actions.declare_file(class_jar_name)
    _busybox.generate_binary_r(
        ctx,
        out_class_jar = class_jar,
        r_txt = r_txt,
        manifest = processed_manifest,
        package_for_r = java_package,
        final_fields = not shrink_resource_cycles and not instruments,
        resources_nodes = depset(transitive = direct_resources_nodes + transitive_resources_nodes),
        transitive_r_txts = transitive_r_txts,
        transitive_manifests = transitive_manifests,
        busybox = busybox,
        host_javabase = host_javabase,
    )
    packaged_resources_ctx[_PACKAGED_CLASS_JAR] = class_jar

    java_info = JavaInfo(
        output_jar = class_jar,
        compile_jar = class_jar,
        source_jar = r_java,
    )

    packaged_resources_ctx[_R_JAVA] = java_info

    packaged_resources_ctx[_PROVIDERS].append(AndroidApplicationResourceInfo(
        resource_apk = resource_apk,
        resource_java_src_jar = r_java,
        resource_java_class_jar = class_jar,
        manifest = processed_manifest,
        resource_proguard_config = proguard_cfg,
        main_dex_proguard_config = main_dex_proguard_cfg,
        r_txt = r_txt,
        resources_zip = resource_files_zip,
        databinding_info = databinding_info,
    ))
    return _ResourcesPackageContextInfo(**packaged_resources_ctx)

def _liteparse(ctx, out_r_pb, resource_files, android_kit):
    """Creates an R.pb which contains the resource ids gotten from a light parse.

    Args:
      ctx: The context.
      out_r_pb: File. The R.pb output file.
      resource_files: List of Files. The list of resource files.
      android_kit: FilesToRunProvider. The Android Kit executable or
        FilesToRunProvider.
    """
    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "--flagfile=%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add_joined("--res_files", resource_files, join_with = ",")
    args.add("--out", out_r_pb)

    ctx.actions.run(
        executable = android_kit,
        arguments = ["liteparse", args],
        inputs = resource_files,
        outputs = [out_r_pb],
        mnemonic = "ResLiteParse",
        progress_message = "Lite parse Android Resources %s" % ctx.label,
    )

def _fastr(ctx, r_pbs, package, manifest, android_kit):
    """Create R.srcjar from the given R.pb files in the transitive closure.

    Args:
      ctx: The context.
      r_pbs: Transitive  set of resource pbs.
      package: The package name of the compile-time R.java.
      manifest: File. The AndroidManifest.xml file.
      android_kit: FilesToRunProvider. The Android Kit executable or
        FilesToRunProvider.

    Returns:
      The output R source jar artifact.
    """
    inputs = r_pbs
    r_srcjar = ctx.actions.declare_file(ctx.label.name + "/resources/R-fastr.srcjar")
    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "--flagfile=%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add("-rJavaOutput", r_srcjar)
    if package:
        args.add("-packageForR", package)
    else:
        args.add("-manifest", manifest)
        inputs = depset([manifest], transitive = [inputs])
    args.add_joined("-resourcePbs", r_pbs, join_with = ",")

    ctx.actions.run(
        executable = android_kit,
        arguments = ["rstub", args],
        inputs = inputs,
        outputs = [r_srcjar],
        mnemonic = "CompileTimeR",
        progress_message = "Generating compile-time R %s" % r_srcjar.short_path,
    )
    return r_srcjar

def _compile(
        ctx,
        out_compiled_resources = None,
        out_r_pb = None,
        resource_files = [],
        aapt = None,
        android_kit = None,
        busybox = None,
        host_javabase = None):
    """Compile Android Resources processing pipeline.

    Args:
      ctx: The context.
      out_compiled_resources: File. The compiled resources output file.
      out_r_pb: File. The R.pb output file.
      resource_files: A list of Files. The resource files can be directories.
      aapt: FilesToRunProvider. The aapt executable or FilesToRunProvider.
      android_kit: FilesToRunProvider. The android_kit executable or
        FilesToRunProvider.
      busybox: FilesToRunProvider. The ResourceBusyBox executable or
        FilesToRunprovider
      host_javabase: A Target. The host javabase.
    """
    _liteparse(ctx, out_r_pb, resource_files, android_kit)
    _busybox.compile(
        ctx,
        out_file = out_compiled_resources,
        resource_files = resource_files,
        aapt = aapt,
        busybox = busybox,
        host_javabase = host_javabase,
    )

def _make_aar(
        ctx,
        assets = [],
        assets_dir = None,
        resource_files = [],
        class_jar = None,
        r_txt = None,
        manifest = None,
        proguard_specs = [],
        busybox = None,
        host_javabase = None):
    """Generate an android archive file.

    Args:
      ctx: The context.
      assets: sequence of Files. A list of Android assets files to be processed.
      assets_dir: String. The name of the assets directory.
      resource_files: A list of Files. The resource files.
      class_jar: File. The class jar file.
      r_txt: File. The resource IDs outputted by linking resources in text.
      manifest: File. The primary AndroidManifest.xml.
      proguard_specs: List of File. The proguard spec files.
      busybox: FilesToRunProvider. The ResourceBusyBox executable or
        FilesToRunprovider
      host_javabase: A Target. The host javabase.

    Returns:
      The output aar artifact.
    """
    aar = ctx.actions.declare_file(ctx.label.name + ".aar")
    _busybox.make_aar(
        ctx,
        out_aar = aar,
        assets = assets,
        assets_dir = assets_dir,
        resource_files = resource_files,
        class_jar = class_jar,
        r_txt = r_txt,
        manifest = manifest,
        proguard_specs = proguard_specs,
        busybox = busybox,
        host_javabase = host_javabase,
    )
    return aar

def _validate(ctx, manifest, defined_assets, defined_assets_dir):
    if ((defined_assets and not defined_assets_dir) or
        (not defined_assets and defined_assets_dir)):
        _log.error(_ASSET_DEFINITION_ERROR % ctx.label)

    if not manifest:
        _log.error(_MANIFEST_MISSING_ERROR % ctx.label)

def _make_direct_assets_transitive(assets_info):
    return AndroidAssetsInfo(
        assets_info.label,
        assets_info.validation_result,
        depset([]),  # direct_parsed_assets
        depset(
            transitive = [
                assets_info.direct_parsed_assets,
                assets_info.transitive_parsed_assets,
            ],
            order = "preorder",
        ),
        assets_info.assets,
        assets_info.symbols,
        assets_info.compiled_symbols,
    )

def _make_direct_resources_transitive(resources_info):
    return AndroidResourcesInfo(
        resources_info.label,
        resources_info.manifest,
        resources_info.compiletime_r_txt,
        # NB: the ordering of "direct" and "transitive" is inconsistent with that used for
        # AndroidAssetsInfo.
        depset(
            transitive = [
                # Ordering is inconsistent here too:
                # https://github.com/bazelbuild/bazel/blob/82c7f48b4628ebbec18123afdbed701bbaa605e2/src/tools/android/java/com/google/devtools/build/android/Aapt2ResourcePackagingAction.java#L158
                resources_info.transitive_android_resources,
                resources_info.direct_android_resources,
            ],
            order = "preorder",
        ),
        depset([]),  # direct_android_resources
        resources_info.transitive_resources,
        resources_info.transitive_manifests,
        resources_info.transitive_aapt2_r_txt,
        resources_info.transitive_symbols_bin,
        resources_info.transitive_compiled_symbols,
        resources_info.transitive_static_lib,
        resources_info.transitive_r_txt,
        validation_artifacts = resources_info.validation_artifacts,
    )

def _export_assets(assets_info, exports):
    all_providers = [assets_info] + utils.collect_providers(AndroidAssetsInfo, exports)
    return AndroidAssetsInfo(
        assets_info.label,
        assets_info.validation_result,
        direct_parsed_assets = utils.join_depsets(all_providers, "direct_parsed_assets", order = "preorder"),
        transitive_parsed_assets = utils.join_depsets(all_providers, "transitive_parsed_assets", order = "preorder"),
        transitive_assets = utils.join_depsets(all_providers, "assets", order = "preorder"),
        transitive_symbols = utils.join_depsets(all_providers, "symbols", order = "preorder"),
        transitive_compiled_symbols = utils.join_depsets(all_providers, "compiled_symbols", order = "preorder"),
    )

def _export_resources(resources_info, exports):
    all_providers = [resources_info] + utils.collect_providers(AndroidResourcesInfo, exports)
    return AndroidResourcesInfo(
        resources_info.label,
        resources_info.manifest,
        resources_info.compiletime_r_txt,
        **{attr: utils.join_depsets(all_providers, attr, order = "preorder") for attr in [
            "transitive_android_resources",
            "direct_android_resources",
            "transitive_resources",
            "transitive_manifests",
            "transitive_aapt2_r_txt",
            "transitive_symbols_bin",
            "transitive_compiled_symbols",
            "transitive_static_lib",
            "transitive_r_txt",
            "validation_artifacts",
        ]}
    )

def _validate_resources(resource_files = None):
    for resource_file in resource_files:
        path_segments = resource_file.path.split("/")
        if len(path_segments) < 3:
            fail(_INCORRECT_RESOURCE_LAYOUT_ERROR % resource_file)

        # Check the resource directory type if the resource file is not a Fileset.
        if not resource_file.is_directory:
            # The resource directory is presumed to be the second directory from the end.
            # Resource directories can have multiple qualifiers, each one separated with a dash.
            res_type = path_segments[-2].partition(_RESOURCE_QUALIFIER_SEP)[0]
            if res_type not in _RESOURCE_FOLDER_TYPES:
                fail(_INCORRECT_RESOURCE_LAYOUT_ERROR % resource_file)

def _process_starlark(
        ctx,
        java_package = None,
        manifest = None,
        defined_assets = False,
        assets = None,
        defined_assets_dir = False,
        assets_dir = None,
        exports_manifest = False,
        stamp_manifest = True,
        deps = [],
        exports = [],
        resource_files = None,
        neverlink = False,
        enable_data_binding = False,
        android_test_migration = False,
        fix_resource_transitivity = False,
        aapt = None,
        android_jar = None,
        android_kit = None,
        busybox = None,
        java_toolchain = None,
        host_javabase = None,
        instrument_xslt = None,
        xsltproc = None,
        zip_tool = None):
    """Processes Android Resources.

    Args:
      ctx: The rules context.
      java_package: string. Java package for which java sources will be
        generated. By default the package is inferred from the directory where
        the BUILD file containing the rule is.
      manifest: File. The AndroidManifest.xml file.
      defined_assets: Bool. Signifies that the assets attribute was set, even
        if the value is an empty list.
      assets: sequence of Files. A list of Android assets files to be processed.
      defined_assets_dir: Bool. Signifies that the assets dir attribute was set,
        even if the value is an empty string.
      assets_dir: String. The name of the assets directory.
      exports_manifest: boolean. Whether to export manifest entries to the
        android_binary targets that depend on this target.
        NOTE: "uses-permissions" attributes are never exported.
      stamp_manifest: boolean. Whether to stamp the manifest with the java
        package of the target. If True, java_package needs to be passed to
        the function.
      deps: sequence of Targets. The list of other libraries targets to link
        against.
      exports: sequence of Targets. The closure of all rules reached via exports
        attributes are considered direct dependencies of any rule that directly
        depends on the target with exports. The exports are not direct deps of
        the rule they belong to (TODO(b/144134042): make this so).
      resource_files: sequence of Files. A list of Android resource files to be
        processed.
      neverlink: boolean. Only use this library for compilation and not runtime.
        The outputs of a rule marked as neverlink will not be used in .apk
        creation. Useful if the library will be provided by the runtime
        environment during execution.
      enable_data_binding: boolean. If true, processesing the data binding
        expressions in layout resources included through the resource_files
        parameter is enabled. Without this setting, data binding expressions
        produce build failures.
      android_test_migration: boolean. If true, the target is part of the android
      test to android instrumentation test migration and should not propagate
      any Android Resource providers.
      fix_resource_transitivity: Whether to ensure that transitive resources are
        correctly marked as transitive.
      aapt: FilesToRunProvider. The aapt executable or FilesToRunProvider.
      android_jar: File. The android Jar.
      android_kit: FilesToRunProvider. The android_kit executable or
        FilesToRunProvider.
      busybox: FilesToRunProvider. The ResourceBusyBox executable or
        FilesToRunprovider
      java_toolchain: The java_toolchain Target.
      host_javabase: Target. The host javabase.
      instrument_xslt: File. The xslt transform to apply g3itr.
      xsltproc: FilesToRunProvider. The xsltproc executable or FilesToRunProvider.
      zip_tool: FilesToRunProvider. The zip tool executable or FilesToRunProvider.

    Returns:
      A dict containing _ResourcesProcessContextInfo provider fields.
    """
    if (xsltproc and not instrument_xslt) or (not xsltproc and instrument_xslt):
        fail(
            "Error, both instrument_xslt and xsltproc need to be " +
            "specified or not, got:\nxlstproc = %s\ninstrument_xslt = %s" %
            (xsltproc, instrument_xslt),
        )

    _validate_resources(resource_files)

    defines_resources = bool(
        manifest or
        resource_files or
        defined_assets or
        defined_assets_dir or
        exports_manifest,
    )

    # TODO(djwhang): Clean up the difference between neverlink the attribute used
    # by Java compilation and resources neverlink.
    resources_neverlink = (
        neverlink and (
            defines_resources or
            ctx.fragments.android.fixed_resource_neverlinking
        )
    )

    resources_ctx = {
        _RESOURCES_APK: None,
        _PROVIDERS: [],
        # TODO(b/156530953): Move the validation result to the validation_outputs list when we are
        # done rolling out Starlark resources processing
        _VALIDATION_RESULTS: [],
        _DEFINES_RESOURCES: defines_resources,
        _R_JAVA: None,
        _MERGED_MANIFEST: None,
        _STARLARK_PROCESSED_MANIFEST: None,
        _STARLARK_R_TXT: None,
        _STARLARK_PROCESSED_RESOURCES: [],
    }

    if resource_files and not manifest:
        _log.error(_MANIFEST_MISSING_ERROR % ctx.label)

    if stamp_manifest and not java_package:
        _log.error(_JAVA_PACKAGE_MISSING_ERROR % ctx.label)

    direct_resources_nodes = []
    transitive_resources_nodes = []
    transitive_assets = []
    transitive_assets_symbols = []
    transitive_compiled_assets = []
    direct_compiled_resources = []
    transitive_compiled_resources = []
    transitive_resources_files = []
    transitive_manifests = []
    transitive_r_txts = []

    for dep in utils.collect_providers(StarlarkAndroidResourcesInfo, deps):
        direct_resources_nodes.append(dep.direct_resources_nodes)
        transitive_resources_nodes.append(dep.transitive_resources_nodes)
        transitive_assets.append(dep.transitive_assets)
        transitive_assets_symbols.append(dep.transitive_assets_symbols)
        transitive_compiled_assets.append(dep.transitive_compiled_assets)
        direct_compiled_resources.append(dep.direct_compiled_resources)
        transitive_compiled_resources.append(dep.transitive_compiled_resources)
        transitive_resources_files.append(dep.transitive_resource_files)
        transitive_manifests.append(dep.transitive_manifests)
        transitive_r_txts.append(dep.transitive_r_txts)

    exports_direct_resources_nodes = []
    exports_transitive_resources_nodes = []
    exports_transitive_assets = []
    exports_transitive_assets_symbols = []
    exports_transitive_compiled_assets = []
    exports_direct_compiled_resources = []
    exports_transitive_compiled_resources = []
    exports_transitive_resources_files = []
    exports_transitive_manifests = []
    exports_transitive_r_txts = []
    for dep in utils.collect_providers(StarlarkAndroidResourcesInfo, exports):
        exports_direct_resources_nodes.append(dep.direct_resources_nodes)
        exports_transitive_resources_nodes.append(dep.transitive_resources_nodes)
        exports_transitive_assets.append(dep.transitive_assets)
        exports_transitive_assets_symbols.append(dep.transitive_assets_symbols)
        exports_transitive_compiled_assets.append(dep.transitive_compiled_assets)
        exports_direct_compiled_resources.append(dep.direct_compiled_resources)
        exports_transitive_compiled_resources.append(dep.transitive_compiled_resources)
        exports_transitive_resources_files.append(dep.transitive_resource_files)
        exports_transitive_manifests.append(dep.transitive_manifests)
        exports_transitive_r_txts.append(dep.transitive_r_txts)

    # TODO(b/144134042): Don't merge exports; exports are not deps.
    direct_resources_nodes.extend(exports_direct_resources_nodes)
    transitive_resources_nodes.extend(exports_transitive_resources_nodes)
    transitive_assets.extend(exports_transitive_assets)
    transitive_assets_symbols.extend(exports_transitive_assets_symbols)
    transitive_compiled_assets.extend(exports_transitive_compiled_assets)
    direct_compiled_resources.extend(exports_direct_compiled_resources)
    transitive_compiled_resources.extend(exports_transitive_compiled_resources)
    transitive_resources_files.extend(exports_transitive_resources_files)
    transitive_manifests.extend(exports_transitive_manifests)
    transitive_r_txts.extend(exports_transitive_r_txts)

    compiled_assets = None
    parsed_assets = None
    compiled_resources = None
    out_aapt2_r_txt = None
    r_txt = None
    processed_resources = resource_files
    processed_manifest = None
    if not defines_resources:
        if aapt:
            # Generate an empty manifest with the right package
            generated_manifest = ctx.actions.declare_file(
                "_migrated/_generated/" + ctx.label.name + "/AndroidManifest.xml",
            )
            _generate_dummy_manifest(
                ctx,
                generated_manifest,
                java_package if java_package else ctx.label.package.replace("/", "."),
            )
            r_txt = ctx.actions.declare_file(
                "_migrated/" + ctx.label.name + "_symbols/R.txt",
            )
            out_manifest = ctx.actions.declare_file(
                "_migrated/" + ctx.label.name + "_processed_manifest/AndroidManifest.xml",
            )
            _busybox.package(
                ctx,
                out_r_src_jar = ctx.actions.declare_file(
                    "_migrated/" + ctx.label.name + ".srcjar",
                ),
                out_r_txt = r_txt,
                out_manifest = out_manifest,
                manifest = generated_manifest,
                assets = assets,
                assets_dir = assets_dir,
                resource_files = resource_files,
                direct_resources_nodes =
                    depset(transitive = direct_resources_nodes, order = "preorder"),
                transitive_resources_nodes =
                    depset(transitive = transitive_resources_nodes, order = "preorder"),
                transitive_assets = transitive_assets,
                transitive_compiled_assets = transitive_compiled_assets,
                transitive_resource_files = transitive_resources_files,
                transitive_compiled_resources = transitive_compiled_resources,
                transitive_manifests = transitive_manifests,
                transitive_r_txts = transitive_r_txts,
                package_type = "LIBRARY",
                java_package = java_package,
                android_jar = android_jar,
                aapt = aapt,
                busybox = busybox,
                host_javabase = host_javabase,
                should_throw_on_conflict = False,
            )
            resources_ctx[_STARLARK_PROCESSED_MANIFEST] = out_manifest
            resources_ctx[_STARLARK_R_TXT] = r_txt
            resources_ctx[_STARLARK_PROCESSED_RESOURCES] = resource_files

    else:
        if stamp_manifest:
            stamped_manifest = ctx.actions.declare_file(
                "_migrated/_renamed/" + ctx.label.name + "/AndroidManifest.xml",
            )
            _busybox.merge_manifests(
                ctx,
                out_file = stamped_manifest,
                manifest = manifest,
                merge_type = "LIBRARY",
                java_package = java_package,
                busybox = busybox,
                host_javabase = host_javabase,
            )
            manifest = stamped_manifest

        if instrument_xslt:
            g3itr_manifest = ctx.actions.declare_file(
                "_migrated/" + ctx.label.name + "_g3itr_manifest/AndroidManifest.xml",
            )
            _add_g3itr(
                ctx,
                out_manifest = g3itr_manifest,
                manifest = manifest,
                xsltproc = xsltproc,
                instrument_xslt = instrument_xslt,
            )
            manifest = g3itr_manifest

        parsed_assets = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + "_symbols/assets.bin",
        )
        _busybox.parse(
            ctx,
            out_symbols = parsed_assets,
            assets = assets,
            assets_dir = assets_dir,
            busybox = busybox,
            host_javabase = host_javabase,
        )
        merged_assets = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + "_files/assets.zip",
        )
        _busybox.merge_assets(
            ctx,
            out_assets_zip = merged_assets,
            assets = assets,
            assets_dir = assets_dir,
            symbols = parsed_assets,
            direct_resources_nodes = depset(
                transitive = direct_resources_nodes,
                order = "preorder",
            ),
            transitive_resources_nodes = depset(
                transitive = transitive_resources_nodes,
                order = "preorder",
            ),
            transitive_assets = transitive_assets,
            transitive_assets_symbols = transitive_assets_symbols,
            busybox = busybox,
            host_javabase = host_javabase,
        )
        resources_ctx[_VALIDATION_RESULTS].append(merged_assets)

        if assets:
            compiled_assets = ctx.actions.declare_file(
                "_migrated/" + ctx.label.name + "_symbols/assets.zip",
            )
            _busybox.compile(
                ctx,
                out_file = compiled_assets,
                assets = assets,
                assets_dir = assets_dir,
                aapt = aapt,
                busybox = busybox,
                host_javabase = host_javabase,
            )

        if enable_data_binding:
            out_databinding_info = ctx.actions.declare_file(
                "_migrated/databinding/" + ctx.label.name + "/layout-info.zip",
            )
            processed_resources, resources_dirname = _make_databinding_outputs(
                ctx,
                resource_files,
            )
            _busybox.process_databinding(
                ctx,
                out_databinding_info = out_databinding_info,
                out_databinding_processed_resources = processed_resources,
                databinding_resources_dirname = resources_dirname,
                resource_files = resource_files,
                java_package = java_package,
                busybox = busybox,
                host_javabase = host_javabase,
            )

        compiled_resources = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + "_symbols/symbols.zip",
        )
        _busybox.compile(
            ctx,
            out_file = compiled_resources,
            resource_files = processed_resources,
            aapt = aapt,
            busybox = busybox,
            host_javabase = host_javabase,
        )

        # TODO(b/160907203): Remove this fix once the native resource processing pipeline is turned off.
        if enable_data_binding:
            fixed_compiled_resources = ctx.actions.declare_file(
                "_migrated/fixed/" + ctx.label.name + "_symbols/symbols.zip",
            )
            _fix_databinding_compiled_resources(
                ctx,
                out_compiled_resources = fixed_compiled_resources,
                compiled_resources = compiled_resources,
                zip_tool = zip_tool,
            )
            compiled_resources = fixed_compiled_resources

        out_class_jar = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + "_resources.jar",
        )
        processed_manifest = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + "_processed_manifest/AndroidManifest.xml",
        )
        out_aapt2_r_txt = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + "_symbols/R.aapt2.txt",
        )
        _busybox.merge_compiled(
            ctx,
            out_class_jar = out_class_jar,
            out_manifest = processed_manifest,
            out_aapt2_r_txt = out_aapt2_r_txt,
            java_package = java_package,
            manifest = manifest,
            compiled_resources = compiled_resources,
            direct_resources_nodes =
                depset(transitive = direct_resources_nodes, order = "preorder"),
            transitive_resources_nodes = depset(
                transitive = transitive_resources_nodes,
                order = "preorder",
            ),
            direct_compiled_resources = depset(
                transitive = direct_compiled_resources,
                order = "preorder",
            ),
            transitive_compiled_resources = depset(
                transitive = transitive_compiled_resources,
                order = "preorder",
            ),
            android_jar = android_jar,
            busybox = busybox,
            host_javabase = host_javabase,
        )
        resources_ctx[_MERGED_MANIFEST] = processed_manifest

        apk = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + "_files/library.ap_",
        )
        r_java = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + ".srcjar",
        )
        r_txt = ctx.actions.declare_file(
            "_migrated/" + ctx.label.name + "_symbols/R.txt",
        )
        _busybox.validate_and_link(
            ctx,
            out_r_src_jar = r_java,
            out_r_txt = r_txt,
            out_file = apk,
            compiled_resources = compiled_resources,
            transitive_compiled_resources = depset(
                transitive = transitive_compiled_resources,
                order = "preorder",
            ),
            java_package = java_package,
            manifest = processed_manifest,
            android_jar = android_jar,
            aapt = aapt,
            busybox = busybox,
            host_javabase = host_javabase,
        )
        resources_ctx[_RESOURCES_APK] = apk

        java_info = JavaInfo(
            output_jar = out_class_jar,
            compile_jar = out_class_jar,
            source_jar = r_java,
        )

        resources_ctx[_R_JAVA] = java_info

        # In a normal build, the outputs of _busybox.validate_and_link are unused. However we need
        # this action to run to support resource visibility checks.
        resources_ctx[_VALIDATION_RESULTS].append(r_txt)

        # Needed for AAR generation. The Starlark resource processing pipeline uses the aapt2_r_txt file,
        # which is why we can't use the StarlarkAndroidResourcesInfo provider when generating the aar.
        resources_ctx[_STARLARK_PROCESSED_MANIFEST] = processed_manifest
        resources_ctx[_STARLARK_R_TXT] = r_txt
        resources_ctx[_STARLARK_PROCESSED_RESOURCES] = processed_resources

    # TODO(b/117338320): Transitive lists defined here are incorrect; direct should come
    # before transitive, and the order should be topological order instead of preorder.
    # However, some applications may depend on this incorrect order.
    if defines_resources:
        transitive_resources_nodes = transitive_resources_nodes + direct_resources_nodes
        direct_resources_nodes = []
        transitive_compiled_resources = transitive_compiled_resources + direct_compiled_resources
        direct_compiled_resources = []
    else:
        if fix_resource_transitivity:
            transitive_resources_nodes = transitive_resources_nodes + direct_resources_nodes
            direct_resources_nodes = []
            transitive_compiled_resources = transitive_compiled_resources + direct_compiled_resources
            direct_compiled_resources = []

        # TODO(b/144163743): If the resource transitivity fix is disabled and resources-related
        # inputs are missing, we implicitly export deps here. This legacy behavior must exist in the
        # Starlark resource processing pipeline until we can clean up the depot.

    # TODO(b/159916013): Audit neverlink behavior. Some processing can likely be skipped if the target is neverlink.
    # TODO(b/69668042): Don't propagate exported providers/artifacts. Exports should respect neverlink.
    if resources_neverlink:
        resources_ctx[_PROVIDERS].append(StarlarkAndroidResourcesInfo(
            direct_resources_nodes = depset(
                transitive = exports_direct_resources_nodes,
                order = "preorder",
            ),
            transitive_resources_nodes = depset(
                transitive = exports_transitive_resources_nodes,
                order = "preorder",
            ),
            transitive_assets = depset(
                transitive = exports_transitive_assets,
                order = "preorder",
            ),
            transitive_assets_symbols = depset(
                transitive = exports_transitive_assets_symbols,
                order = "preorder",
            ),
            transitive_compiled_assets = depset(
                transitive = exports_transitive_compiled_assets,
                order = "preorder",
            ),
            transitive_resource_files = depset(
                transitive = exports_transitive_resources_files,
                order = "preorder",
            ),
            direct_compiled_resources = depset(
                transitive = exports_direct_compiled_resources,
                order = "preorder",
            ),
            transitive_compiled_resources = depset(
                transitive = exports_transitive_compiled_resources,
                order = "preorder",
            ),
            transitive_manifests = depset(
                [processed_manifest] if processed_manifest else [],
                transitive = exports_transitive_manifests,
                order = "preorder",
            ),
            transitive_r_txts = depset(
                [out_aapt2_r_txt] if out_aapt2_r_txt else [],
                transitive = exports_transitive_r_txts,
                order = "preorder",
            ),
        ))
    else:
        # Depsets are ordered below to match the order in the legacy native rules.
        resources_ctx[_PROVIDERS].append(StarlarkAndroidResourcesInfo(
            direct_resources_nodes = depset(
                [ResourcesNodeInfo(
                    label = ctx.label,
                    assets = depset(assets),
                    assets_dir = assets_dir,
                    assets_symbols = parsed_assets,
                    compiled_assets = compiled_assets,
                    resource_files = depset(processed_resources),
                    compiled_resources = compiled_resources,
                    r_txt = out_aapt2_r_txt,
                    manifest = processed_manifest,
                    exports_manifest = exports_manifest,
                )] if defines_resources else [],
                transitive = direct_resources_nodes + exports_direct_resources_nodes,
                order = "preorder",
            ),
            transitive_resources_nodes = depset(
                transitive = transitive_resources_nodes + exports_transitive_resources_nodes,
                order = "preorder",
            ),
            transitive_assets = depset(
                assets,
                transitive = transitive_assets + exports_transitive_assets,
                order = "preorder",
            ),
            transitive_assets_symbols = depset(
                [parsed_assets] if parsed_assets else [],
                transitive = transitive_assets_symbols + exports_transitive_assets_symbols,
                order = "preorder",
            ),
            transitive_compiled_assets = depset(
                [compiled_assets] if compiled_assets else [],
                transitive = transitive_compiled_assets + exports_transitive_compiled_assets,
                order = "preorder",
            ),
            transitive_resource_files = depset(
                processed_resources,
                transitive = transitive_resources_files + exports_transitive_resources_files,
                order = "preorder",
            ),
            direct_compiled_resources = depset(
                [compiled_resources] if compiled_resources else [],
                transitive = direct_compiled_resources + exports_direct_compiled_resources,
                order = "preorder",
            ),
            transitive_compiled_resources = depset(
                [compiled_resources] if compiled_resources else [],
                transitive = transitive_compiled_resources + exports_transitive_compiled_resources,
                order = "preorder",
            ),
            transitive_manifests = depset(
                [processed_manifest] if processed_manifest else [],
                transitive = transitive_manifests + exports_transitive_manifests,
                order = "preorder",
            ),
            transitive_r_txts = depset(
                [out_aapt2_r_txt] if out_aapt2_r_txt else [],
                transitive = transitive_r_txts + exports_transitive_r_txts,
                order = "preorder",
            ),
        ))

    # Do not collect resources and R.java for test apk
    if android_test_migration:
        resources_ctx[_R_JAVA] = None
        resources_ctx[_PROVIDERS] = []

    # TODO(b/69552500): In the Starlark Android Rules, the R compile time
    # JavaInfo is added as a runtime dependency to the JavaInfo. Stop
    # adding the R.jar as a runtime dependency.
    resources_ctx[_PROVIDERS].append(
        AndroidLibraryResourceClassJarProvider(
            depset(
                (resources_ctx[_R_JAVA].runtime_output_jars if resources_ctx[_R_JAVA] else []),
                transitive = [
                    p.jars
                    for p in utils.collect_providers(
                        AndroidLibraryResourceClassJarProvider,
                        deps,
                        exports,
                    )
                ],
                order = "preorder",
            ),
        ),
    )

    return resources_ctx


def _process(
        ctx,
        manifest = None,
        resource_files = None,
        defined_assets = False,
        assets = None,
        defined_assets_dir = False,
        assets_dir = None,
        exports_manifest = False,
        java_package = None,
        custom_package = None,
        neverlink = False,
        enable_data_binding = False,
        deps = [],
        exports = [],
        android_jar = None,
        android_kit = None,
        aapt = None,
        busybox = None,
        xsltproc = None,
        instrument_xslt = None,
        java_toolchain = None,
        host_javabase = None,
        enable_res_v3 = False,
        res_v3_dummy_manifest = None,
        res_v3_dummy_r_txt = None,
        fix_resource_transitivity = False,
        fix_export_exporting = False,
        android_test_migration = False,
        zip_tool = None):
    out_ctx = _process_starlark(
        ctx,
        java_package = java_package,
        manifest = manifest,
        defined_assets = defined_assets,
        # TODO(b/159937795): When the Starlark Resources Processing pipeline is
        # default and the native version is no longer used, remove the depset
        # creation and directly pass through ctx.files.assets to this method.
        assets =
            depset(transitive = [target.files for target in assets]).to_list(),
        defined_assets_dir = defined_assets_dir,
        assets_dir = assets_dir,
        exports_manifest = exports_manifest,
        stamp_manifest = True if java_package else False,
        deps = deps,
        exports = exports,
        resource_files = depset(transitive = [target.files for target in resource_files]).to_list(),
        enable_data_binding = enable_data_binding,
        fix_resource_transitivity = fix_resource_transitivity,
        neverlink = neverlink,
        android_test_migration = android_test_migration,
        android_jar = android_jar,
        aapt = aapt,
        android_kit = android_kit,
        busybox = busybox,
        instrument_xslt = instrument_xslt,
        xsltproc = xsltproc,
        java_toolchain = java_toolchain,
        host_javabase = host_javabase,
        zip_tool = zip_tool,
    )


    if _VALIDATION_OUTPUTS not in out_ctx:
        out_ctx[_VALIDATION_OUTPUTS] = []

    return _ResourcesProcessContextInfo(**out_ctx)

resources = struct(
    process = _process,
    process_starlark = _process_starlark,
    package = _package,
    make_aar = _make_aar,

    # Exposed for mobile-install
    compile = _compile,
    legacy_merge_manifests = _legacy_merge_manifests,

    # Exposed for android_local_test and android_library
    generate_dummy_manifest = _generate_dummy_manifest,
)

testing = struct(
    add_g3itr = _add_g3itr,
    filter_multi_cpu_configuration_targets = _filter_multi_cpu_configuration_targets,
    get_legacy_mergee_manifests = _get_legacy_mergee_manifests,
    make_databinding_outputs = _make_databinding_outputs,
    ResourcesPackageContextInfo = _ResourcesPackageContextInfo,
    ResourcesProcessContextInfo = _ResourcesProcessContextInfo,
)
