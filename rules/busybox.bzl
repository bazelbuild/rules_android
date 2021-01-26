# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Bazel ResourcesBusyBox Commands."""

load(":java.bzl", _java = "java")

_ANDROID_RESOURCES_STRICT_DEPS = "android_resources_strict_deps"

def _sanitize_assets_dir(assets_dir):
    sanitized_assets_dir = "/".join(
        [
            part
            for part in assets_dir.split("/")
            if part != "" and part != "."
        ],
    )

    return "/" + sanitized_assets_dir if assets_dir.startswith("/") else sanitized_assets_dir

def _get_unique_assets_dirs(assets, assets_dir):
    """Find the unique assets directories, partitioned by assets_dir.

    Args:
      assets: A list of Files. List of asset files to process.
      assets_dir: String. String giving the path to the files in assets.

    Returns:
      A list of short_paths representing unique asset dirs.
    """
    if not assets:
        return []

    dirs = dict()

    assets_dir = _sanitize_assets_dir(assets_dir)
    if assets_dir:
        partition_by = "/%s/" % assets_dir.strip("/")
        for f in assets:
            if f.is_directory and f.path.endswith(partition_by[:-1]):
                # If f is a directory, check if its path ends with the assets_dir.
                dirs[f.path] = True
            elif f.is_directory and "_aar/unzipped" in f.path:
                # Assets from an aar_import rule are extracted in a
                # "assets" subdirectory of the given path
                dirs["%s/assets" % f.path] = True
            else:
                # Partition to remove subdirectories beneath assets_dir
                # Also removes the trailing /
                dirs["".join(f.path.rpartition(partition_by)[:2])[:-1]] = True
    else:
        # Use the dirname of the generating target if no assets_dir.
        for f in assets:
            if f.is_source:
                dirs[f.owner.package] = True
            else:
                # Prepend the root path for generated files.
                dirs[f.root.path + "/" + f.owner.package] = True
    return dirs.keys()

def _get_unique_res_dirs(resource_files):
    """Find the unique res dirs.

    Args:
      resource_files: A list of Files. A list of resource_files.

    Returns:
      A list of short_paths representing unique res dirs from the given resource files.
    """
    dirs = dict()
    for f in resource_files:
        if f.is_directory:
            dirs[f.path] = True
        else:
            dirs[f.dirname.rpartition("/" + f.dirname.split("/")[-1])[0]] = True
    return dirs.keys()

def _make_serialized_resources_flag(
        assets = [],
        assets_dir = None,
        resource_files = [],
        label = "",
        symbols = None):
    return ";".join(
        [
            "#".join(_get_unique_res_dirs(resource_files)),
            "#".join(_get_unique_assets_dirs(assets, assets_dir)),
            label,
            symbols.path if symbols else "",
        ],
    ).rstrip(":")

def _make_resources_flag(
        assets = [],
        assets_dir = None,
        resource_files = [],
        manifest = None,
        r_txt = None,
        symbols = None):
    return ":".join(
        [
            "#".join(_get_unique_res_dirs(resource_files)),
            "#".join(_get_unique_assets_dirs(assets, assets_dir)),
            manifest.path if manifest else "",
            r_txt.path if r_txt else "",
            symbols.path if symbols else "",
        ],
    )

def _path(f):
    return f.path

def _make_package_resources_flags(resources_node):
    if not (resources_node.manifest and resources_node.r_txt and resources_node.compiled_resources):
        return None
    flag = _make_resources_flag(
        resource_files = resources_node.resource_files.to_list(),
        assets = resources_node.assets.to_list(),
        assets_dir = resources_node.assets_dir,
        manifest = resources_node.manifest,
        r_txt = resources_node.r_txt,
        symbols = resources_node.compiled_resources,
    )
    return flag

def _make_package_assets_flags(resources_node):
    assets = resources_node.assets.to_list()
    if not assets:
        return None
    return _make_serialized_resources_flag(
        assets = assets,
        assets_dir = resources_node.assets_dir,
        label = str(resources_node.label),
        symbols = resources_node.compiled_assets,
    )

def _extract_filters(
        raw_list):
    """Extract densities and resource_configuration filters from raw string lists.

    In BUILD files, string lists can be represented as a list of strings, a single comma-separated
    string, or a combination of both. This method outputs a single list of individual string values,
    which can then be passed directly to resource processing actions. Empty strings are removed and
    the final list is sorted.

    Args:
      raw_list: List of strings. The raw densities or resource configuration filters.

    Returns:
      List of strings extracted from the raw list.
    """
    out_filters = []
    for item in raw_list:
        if "," in item:
            item_list = item.split(",")
            for entry in item_list:
                stripped_entry = entry.strip()
                if stripped_entry:
                    out_filters.append(stripped_entry)
        elif item:
            out_filters.append(item)
    return sorted(out_filters)

def _package(
        ctx,
        out_r_src_jar = None,
        out_r_txt = None,
        out_symbols = None,
        out_manifest = None,
        out_proguard_cfg = None,
        out_main_dex_proguard_cfg = None,
        out_resource_files_zip = None,
        out_file = None,
        package_type = None,
        java_package = None,
        manifest = None,
        assets = [],
        assets_dir = None,
        resource_files = [],
        resource_configs = None,
        densities = [],
        application_id = None,
        direct_resources_nodes = [],
        transitive_resources_nodes = [],
        transitive_manifests = [],
        transitive_assets = [],
        transitive_compiled_assets = [],
        transitive_resource_files = [],
        transitive_compiled_resources = [],
        transitive_r_txts = [],
        additional_apks_to_link_against = [],
        nocompress_extensions = [],
        proto_format = False,
        version_name = None,
        version_code = None,
        android_jar = None,
        aapt = None,
        busybox = None,
        host_javabase = None,
        should_throw_on_conflict = True,  # TODO: read this from allowlist at caller
        debug = True):  # TODO: we will set this to false in prod builds
    """Packages the compiled Android Resources with AAPT.

    Args:
      ctx: The context.
      out_r_src_jar: A File. The R.java outputted by linking resources in a srcjar.
      out_r_txt: A File. The resource IDs outputted by linking resources in text.
      out_symbols: A File. The output zip containing compiled resources.
      out_manifest: A File. The output processed manifest.
      out_proguard_cfg: A File. The proguard config to be generated.
      out_main_dex_proguard_cfg: A File. The main dex proguard config to be generated.
      out_resource_files_zip: A File. The resource files zipped by linking resources.
      out_file: A File. The Resource APK outputted by linking resources.
      package_type: A string. The configuration type to use when packaging.
      java_package: A string. The Java package for the generated R.java.
      manifest: A File. The AndroidManifest.xml.
      assets: sequence of Files. A list of Android assets files to be processed.
      assets_dir: String. The name of the assets directory.
      resource_files: A list of Files. The resource files.
      resource_configs: A list of strings. The list of resource configuration
        filters.
      densities: A list of strings. The list of screen densities to filter for when
        building the apk.
      application_id: An optional string. The applicationId set in manifest values.
      direct_resources_nodes: Depset of ResourcesNodeInfo providers. The set of
        ResourcesNodeInfo from direct dependencies.
      transitive_resources_nodes: Depset of ResourcesNodeInfo providers. The set
        of ResourcesNodeInfo from transitive dependencies (not including directs).
      transitive_manifests: List of Depsets. Depsets contain all transitive manifests.
      transitive_assets: List of Depsets. Depsets contain all transitive assets.
      transitive_compiled_assets: List of Depsets. Depsets contain all transitive
        compiled_assets.
      transitive_resource_files: List of Depsets. Depsets contain all transitive
        resource files.
      transitive_compiled_resources: List of Depsets. Depsets contain all transitive
        compiled_resources.
      transitive_r_txts: List of Depsets. Depsets contain all transitive R txt files.
      additional_apks_to_link_against: A list of Files. Additional APKs to link
        against. Optional.
      nocompress_extensions: A list of strings. File extension to leave uncompressed
        in the apk.
      proto_format: Boolean, whether to generate the resource table in proto format.
      version_name: A string. The version name to stamp the generated manifest with. Optional.
      version_code: A string. The version code to stamp the generated manifest with. Optional.
      android_jar: A File. The Android Jar.
      aapt: A FilesToRunProvider. The AAPT executable.
      busybox: A FilesToRunProvider. The ResourceProcessorBusyBox executable.
      host_javabase: Target. The host javabase.
      should_throw_on_conflict: A boolean. Determines whether an error should be thrown
        when a resource conflict occurs.
      debug: A boolean. Determines whether to enable debugging.
    """
    if not manifest:
        fail("No manifest given, the manifest is mandatory.")

    direct_data_flag = []
    direct_compiled_resources = []

    output_files = []
    input_files = []
    transitive_input_files = []

    args = ctx.actions.args()
    args.use_param_file("@%s")
    args.add("--tool", "AAPT2_PACKAGE")
    args.add("--")
    args.add("--aapt2", aapt.executable)
    args.add_joined(
        "--data",
        transitive_resources_nodes,
        map_each = _make_package_resources_flags,
        join_with = ",",
    )
    args.add_joined(
        "--directData",
        direct_resources_nodes,
        map_each = _make_package_resources_flags,
        join_with = ",",
    )
    args.add_joined(
        "--directAssets",
        direct_resources_nodes,
        map_each = _make_package_assets_flags,
        join_with = "&",
        omit_if_empty = True,
    )
    args.add_joined(
        "--assets",
        transitive_resources_nodes,
        map_each = _make_package_assets_flags,
        join_with = "&",
        omit_if_empty = True,
    )
    transitive_input_files.extend(transitive_resource_files)
    transitive_input_files.extend(transitive_assets)
    transitive_input_files.extend(transitive_compiled_assets)
    transitive_input_files.extend(transitive_compiled_resources)
    transitive_input_files.extend(transitive_manifests)
    transitive_input_files.extend(transitive_r_txts)
    args.add(
        "--primaryData",
        _make_resources_flag(
            manifest = manifest,
            assets = assets,
            assets_dir = assets_dir,
            resource_files = resource_files,
        ),
    )
    input_files.append(manifest)
    input_files.extend(resource_files)
    input_files.extend(assets)
    args.add("--androidJar", android_jar)
    input_files.append(android_jar)
    args.add("--rOutput", out_r_txt)
    output_files.append(out_r_txt)
    if out_symbols:
        args.add("--symbolsOut", out_symbols)
        output_files.append(out_symbols)
    args.add("--srcJarOutput", out_r_src_jar)
    output_files.append(out_r_src_jar)
    if out_proguard_cfg:
        args.add("--proguardOutput", out_proguard_cfg)
        output_files.append(out_proguard_cfg)
    if out_main_dex_proguard_cfg:
        args.add("--mainDexProguardOutput", out_main_dex_proguard_cfg)
        output_files.append(out_main_dex_proguard_cfg)
    args.add("--manifestOutput", out_manifest)
    output_files.append(out_manifest)
    if out_resource_files_zip:
        args.add("--resourcesOutput", out_resource_files_zip)
        output_files.append(out_resource_files_zip)
    if out_file:
        args.add("--packagePath", out_file)
        output_files.append(out_file)
    args.add("--useAaptCruncher=no")  # Unnecessary, used for AAPT1 only but added here to minimize diffs.
    if package_type:
        args.add("--packageType", package_type)
    if debug:
        args.add("--debug")
    if should_throw_on_conflict:
        args.add("--throwOnResourceConflict")
    if resource_configs:
        args.add_joined("--resourceConfigs", _extract_filters(resource_configs), join_with = ",")
    if densities:
        args.add_joined("--densities", _extract_filters(densities), join_with = ",")
    if application_id:
        args.add("--applicationId", application_id)
    if additional_apks_to_link_against:
        args.add_joined(
            "--additionalApksToLinkAgainst",
            additional_apks_to_link_against,
            join_with = ",",
            map_each = _path,
        )
        input_files.extend(additional_apks_to_link_against)
    if nocompress_extensions:
        args.add_joined("--uncompressedExtensions", nocompress_extensions, join_with = ",")
    if proto_format:
        args.add("--resourceTableAsProto")
    if version_name:
        args.add("--versionName", version_name)
    if version_code:
        args.add("--versionCode", version_code)
    args.add("--packageForR", java_package)

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        tools = [aapt],
        arguments = [args],
        inputs = depset(input_files, transitive = transitive_input_files),
        outputs = output_files,
        mnemonic = "PackageAndroidResources",
        progress_message = "Packaging Android Resources in %s" % ctx.label,
    )

def _parse(
        ctx,
        out_symbols = None,
        assets = [],
        assets_dir = None,
        busybox = None,
        host_javabase = None):
    """Parses Android assets.

    Args:
      ctx: The context.
      out_symbols: A File. The output bin containing parsed assets.
      assets: sequence of Files. A list of Android assets files to be processed.
      assets_dir: String. The name of the assets directory.
      busybox: A FilesToRunProvider. The ResourceProcessorBusyBox executable.
      host_javabase: Target. The host javabase.
    """
    args = ctx.actions.args()
    args.use_param_file("@%s")
    args.add("--tool", "PARSE")
    args.add("--")
    args.add(
        "--primaryData",
        _make_resources_flag(
            assets = assets,
            assets_dir = assets_dir,
        ),
    )
    args.add("--output", out_symbols)

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        arguments = [args],
        inputs = assets,
        outputs = [out_symbols],
        mnemonic = "ParseAndroidResources",
        progress_message = "Parsing Android Resources in %s" % out_symbols.short_path,
    )

def _make_merge_assets_flags(resources_node):
    assets = resources_node.assets.to_list()
    if not (assets or resources_node.assets_dir):
        return None
    return _make_serialized_resources_flag(
        assets = assets,
        assets_dir = resources_node.assets_dir,
        label = str(resources_node.label),
        symbols = resources_node.assets_symbols,
    )

def _merge_assets(
        ctx,
        out_assets_zip = None,
        assets = [],
        assets_dir = None,
        symbols = None,
        transitive_assets = [],
        transitive_assets_symbols = [],
        direct_resources_nodes = [],
        transitive_resources_nodes = [],
        busybox = None,
        host_javabase = None):
    """Merges Android assets.

    Args:
      ctx: The context.
      out_assets_zip: A File.
      assets: sequence of Files. A list of Android assets files to be processed.
      assets_dir: String. The name of the assets directory.
      symbols: A File. The parsed assets.
      transitive_assets: Sequence of Depsets. The list of transitive
        assets from deps.
      transitive_assets_symbols: Sequence of Depsets. The list of
        transitive assets_symbols files from deps.
      direct_resources_nodes: Sequence of ResourcesNodeInfo providers. The list
        of ResourcesNodeInfo providers that are direct depencies.
      transitive_resources_nodes: Sequence of ResourcesNodeInfo providers. The
        list of ResourcesNodeInfo providers that are transitive depencies.
      busybox: A FilesToRunProvider. The ResourceProcessorBusyBox executable.
      host_javabase: Target. The host javabase.
    """
    args = ctx.actions.args()
    args.use_param_file("@%s")
    args.add("--tool", "MERGE_ASSETS")
    args.add("--")
    args.add("--assetsOutput", out_assets_zip)
    args.add(
        "--primaryData",
        _make_serialized_resources_flag(
            assets = assets,
            assets_dir = assets_dir,
            label = str(ctx.label),
            symbols = symbols,
        ),
    )
    args.add_joined(
        "--directData",
        direct_resources_nodes,
        map_each = _make_merge_assets_flags,
        join_with = "&",
    )
    args.add_joined(
        "--data",
        transitive_resources_nodes,
        map_each = _make_merge_assets_flags,
        join_with = "&",
    )

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        arguments = [args],
        inputs = depset(
            assets + [symbols],
            transitive = transitive_assets + transitive_assets_symbols,
        ),
        outputs = [out_assets_zip],
        mnemonic = "MergeAndroidAssets",
        progress_message =
            "Merging Android Assets in %s" % out_assets_zip.short_path,
    )

def _validate_and_link(
        ctx,
        out_r_src_jar = None,
        out_r_txt = None,
        out_file = None,
        compiled_resources = None,
        transitive_compiled_resources = depset(),
        java_package = None,
        manifest = None,
        android_jar = None,
        busybox = None,
        host_javabase = None,
        aapt = None):
    """Links compiled Android Resources with AAPT.

    Args:
      ctx: The context.
      out_r_src_jar: A File. The R.java outputted by linking resources in a srcjar.
      out_r_txt: A File. The resource IDs outputted by linking resources in text.
      out_file: A File. The Resource APK outputted by linking resources.
      compiled_resources: A File. The symbols.zip of compiled resources for
        this target.
      transitive_compiled_resources: Depset of Files. The symbols.zip of the
        compiled resources from the transitive dependencies of this target.
      java_package: A string. The Java package for the generated R.java.
      manifest: A File. The AndroidManifest.xml.
      android_jar: A File. The Android Jar.
      busybox: A FilesToRunProvider. The ResourceProcessorBusyBox executable.
      host_javabase: Target. The host javabase.
      aapt: A FilesToRunProvider. The AAPT executable.
    """
    output_files = []
    input_files = [android_jar]
    transitive_input_files = []

    # Retrieves the list of files at runtime when a directory is passed.
    args = ctx.actions.args()
    args.use_param_file("@%s")
    args.add("--tool", "LINK_STATIC_LIBRARY")
    args.add("--")
    args.add("--aapt2", aapt.executable)
    args.add("--libraries", android_jar)
    if compiled_resources:
        args.add("--compiled", compiled_resources)
        input_files.append(compiled_resources)
    args.add_joined(
        "--compiledDep",
        transitive_compiled_resources,
        join_with = ":",
    )
    transitive_input_files.append(transitive_compiled_resources)
    args.add("--manifest", manifest)
    input_files.append(manifest)
    if java_package:
        args.add("--packageForR", java_package)
    args.add("--sourceJarOut", out_r_src_jar)
    output_files.append(out_r_src_jar)
    args.add("--rTxtOut", out_r_txt)
    output_files.append(out_r_txt)
    args.add("--staticLibraryOut", out_file)
    output_files.append(out_file)

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        tools = [aapt],
        arguments = [args],
        inputs = depset(input_files, transitive = transitive_input_files),
        outputs = output_files,
        mnemonic = "LinkAndroidResources",
        progress_message =
            "Linking Android Resources in " + out_file.short_path,
    )

def _compile(
        ctx,
        out_file = None,
        assets = [],
        assets_dir = None,
        resource_files = [],
        busybox = None,
        aapt = None,
        host_javabase = None):
    """Compile and store resources in a single archive.

    Args:
      ctx: The context.
      out_file: File. The output zip containing compiled resources.
      resource_files: A list of Files. The list of resource files or directories
      assets: A list of Files. The list of assets files or directories
        to process.
      assets_dir: String. The name of the assets directory.
      busybox: A FilesToRunProvider. The ResourceProcessorBusyBox executable.
      aapt: AAPT. Tool for compiling resources.
      host_javabase: Target. The host javabase.
    """
    if not out_file:
        fail("No output directory specified.")

    # Retrieves the list of files at runtime when a directory is passed.
    args = ctx.actions.args()
    args.use_param_file("@%s")
    args.add("--tool", "COMPILE_LIBRARY_RESOURCES")
    args.add("--")
    args.add("--aapt2", aapt.executable)
    args.add(
        "--resources",
        _make_resources_flag(
            resource_files = resource_files,
            assets = assets,
            assets_dir = assets_dir,
        ),
    )
    args.add("--output", out_file)

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        tools = [aapt],
        arguments = [args],
        inputs = resource_files + assets,
        outputs = [out_file],
        mnemonic = "CompileAndroidResources",
        progress_message = "Compiling Android Resources in %s" % out_file.short_path,
    )

def _make_merge_compiled_flags(resources_node_info):
    if not resources_node_info.compiled_resources:
        return None
    return _make_serialized_resources_flag(
        label = str(resources_node_info.label),
        symbols = resources_node_info.compiled_resources,
    )

def _merge_compiled(
        ctx,
        out_class_jar = None,
        out_manifest = None,
        out_aapt2_r_txt = None,
        java_package = None,
        manifest = None,
        compiled_resources = None,
        direct_resources_nodes = [],
        transitive_resources_nodes = [],
        direct_compiled_resources = depset(),
        transitive_compiled_resources = depset(),
        android_jar = None,
        busybox = None,
        host_javabase = None):
    """Merges the compile resources.

    Args:
      ctx: The context.
      out_class_jar: A File. The compiled R.java outputted by linking resources.
      out_manifest: A File. The list of resource files or directories
      out_aapt2_r_txt: A File. The resource IDs outputted by linking resources in text.
      java_package: A string. The Java package for the generated R.java.
      manifest: A File. The AndroidManifest.xml.
      compiled_resources: A File. The symbols.zip of compiled resources for this target.
      direct_resources_nodes: Sequence of ResourcesNodeInfo providers. The list
        of ResourcesNodeInfo providers that are direct depencies.
      transitive_resources_nodes: Sequence of ResourcesNodeInfo providers. The
        list of ResourcesNodeInfo providers that are transitive depencies.
      direct_compiled_resources: Depset of Files. A depset of symbols.zip of
        compiled resources from direct dependencies.
      transitive_compiled_resources: Depset of Files. A depset of symbols.zip of
        compiled resources from transitive dependencies.
      android_jar: A File. The Android Jar.
      busybox: A FilesToRunProvider. The ResourceProcessorBusyBox executable.
      host_javabase: Target. The host javabase.
    """
    output_files = []
    input_files = [android_jar]
    transitive_input_files = []

    args = ctx.actions.args()
    args.use_param_file("@%s")
    args.add("--tool", "MERGE_COMPILED")
    args.add("--")
    args.add("--classJarOutput", out_class_jar)
    output_files.append(out_class_jar)
    args.add("--targetLabel", ctx.label)
    args.add("--manifestOutput", out_manifest)
    output_files.append(out_manifest)
    args.add("--rTxtOut", out_aapt2_r_txt)
    output_files.append(out_aapt2_r_txt)
    args.add("--androidJar", android_jar)
    args.add("--primaryManifest", manifest)
    input_files.append(manifest)
    if java_package:
        args.add("--packageForR", java_package)
    args.add(
        "--primaryData",
        _make_serialized_resources_flag(
            label = str(ctx.label),
            symbols = compiled_resources,
        ),
    )
    input_files.append(compiled_resources)
    args.add_joined(
        "--directData",
        direct_resources_nodes,
        map_each = _make_merge_compiled_flags,
        join_with = "&",
    )
    transitive_input_files.append(direct_compiled_resources)
    if _ANDROID_RESOURCES_STRICT_DEPS in ctx.disabled_features:
        args.add_joined(
            "--data",
            transitive_resources_nodes,
            map_each = _make_merge_compiled_flags,
            join_with = "&",
        )
        transitive_input_files.append(transitive_compiled_resources)

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        arguments = [args],
        inputs = depset(input_files, transitive = transitive_input_files),
        outputs = output_files,
        mnemonic = "StarlarkMergeCompiledAndroidResources",
        progress_message =
            "Merging compiled Android Resources in " + out_class_jar.short_path,
    )

def _escape_mv(s):
    """Escapes `:` and `,` in manifest values so they can be used as a busybox flag."""
    return s.replace(":", "\\:").replace(",", "\\,")

def _owner_label(file):
    return "//" + file.owner.package + ":" + file.owner.name

# We need to remove the "/_migrated/" path segment from file paths in order for sorting to
# match the order of the native manifest merging action.
def _manifest_short_path(manifest):
    return manifest.short_path.replace("/_migrated/", "/")

def _mergee_manifests_flag(manifests):
    ordered_manifests = sorted(manifests.to_list(), key = _manifest_short_path)
    entries = []
    for manifest in ordered_manifests:
        label = _owner_label(manifest).replace(":", "\\:")
        entries.append((manifest.path + ":" + label).replace(",", "\\,"))
    flag_entry = ",".join(entries)
    if not flag_entry:
        return None
    return flag_entry

def _merge_manifests(
        ctx,
        out_file = None,
        out_log_file = None,
        merge_type = "APPLICATION",
        manifest = None,
        mergee_manifests = depset(),
        manifest_values = None,
        java_package = None,
        busybox = None,
        host_javabase = None):
    """Merge multiple AndroidManifest.xml files into a single one.

    Args:
      ctx: The context.
      out_file: A File. The output merged manifest.
      out_log_file: A File. The output log from the merge tool.
      merge_type: A string, either APPLICATION or LIBRARY. Type of merging.
      manifest: A File. The primary AndroidManifest.xml.
      mergee_manifests: A depset of Files. All transitive manifests to be merged.
      manifest_values: A dictionary. Manifest values to substitute.
      java_package: A string. Custom java package to insert in manifest package attribute.
      busybox: A FilesToRunProvider. The ResourceProcessorBusyBox executable.
      host_javabase: Target. The host javabase.
    """
    if merge_type not in ["APPLICATION", "LIBRARY"]:
        fail("Unexpected manifest merge type: " + merge_type)

    outputs = [out_file]
    directs = [manifest]
    transitives = [mergee_manifests]

    # Args for busybox
    args = ctx.actions.args()
    args.use_param_file("@%s", use_always = True)
    args.add("--tool", "MERGE_MANIFEST")
    args.add("--")
    args.add("--manifest", manifest)
    args.add_all(
        "--mergeeManifests",
        [mergee_manifests],
        map_each = _mergee_manifests_flag,
    )
    if manifest_values:
        args.add(
            "--manifestValues",
            ",".join(["%s:%s" % (_escape_mv(k), _escape_mv(v)) for k, v in manifest_values.items()]),
        )
    args.add("--mergeType", merge_type)
    args.add("--customPackage", java_package)
    args.add("--manifestOutput", out_file)
    if out_log_file:
        args.add("--log", out_log_file)
        outputs.append(out_log_file)

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        arguments = [args],
        inputs = depset(directs, transitive = transitives),
        outputs = outputs,
        mnemonic = "MergeManifests",
        progress_message = "Merging Android Manifests in %s" % out_file.short_path,
    )

def _process_databinding(
        ctx,
        out_databinding_info = None,
        out_databinding_processed_resources = None,
        databinding_resources_dirname = None,
        resource_files = None,
        java_package = None,
        busybox = None,
        host_javabase = None):
    """Processes databinding for android_binary.

    Processes databinding declarations over resources, populates the databinding layout
    info file, and generates new resources with databinding expressions stripped out.

    Args:
      ctx: The context.
      out_databinding_info: File. The output databinding layout info zip file.
      out_databinding_processed_resources: List of Files. The generated databinding
        processed resource files.
      databinding_resources_dirname: String. The execution path to the directory where
      the out_databinding_processed_resources are generated.
      resource_files: List of Files. The resource files to be processed.
      java_package: String. Java package for which java sources will be
        generated. By default the package is inferred from the directory where
        the BUILD file containing the rule is.
      busybox: FilesToRunProvider. The ResourceBusyBox executable or
        FilesToRunprovider
      host_javabase: A Target. The host javabase.
    """
    res_dirs = _get_unique_res_dirs(resource_files)

    args = ctx.actions.args()
    args.add("--tool", "PROCESS_DATABINDING")
    args.add("--")
    args.add("--output_resource_directory", databinding_resources_dirname)
    args.add_all(res_dirs, before_each = "--resource_root")
    args.add("--dataBindingInfoOut", out_databinding_info)
    args.add("--appId", java_package)

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        arguments = [args],
        inputs = resource_files,
        outputs = [out_databinding_info] + out_databinding_processed_resources,
        mnemonic = "StarlarkProcessDatabinding",
        progress_message = "Processing data binding",
    )

def _make_generate_binay_r_flags(resources_node):
    if not (resources_node.r_txt or resources_node.manifest):
        return None
    return ",".join(
        [
            resources_node.r_txt.path if resources_node.r_txt else "",
            resources_node.manifest.path if resources_node.manifest else "",
        ],
    )

def _generate_binary_r(
        ctx,
        out_class_jar = None,
        r_txt = None,
        manifest = None,
        package_for_r = None,
        final_fields = None,
        resources_nodes = depset(),
        transitive_r_txts = [],
        transitive_manifests = [],
        busybox = None,
        host_javabase = None):
    """Generate compiled resources class jar.

    Args:
      ctx: The context.
      out_class_jar: File. The output class jar file.
      r_txt: File. The resource IDs outputted by linking resources in text.
      manifest: File. The primary AndroidManifest.xml.
      package_for_r: String. The Java package for the generated R class files.
      final_fields: Bool. Whether fields get declared as final.
      busybox: FilesToRunProvider. The ResourceBusyBox executable or
        FilesToRunprovider
      host_javabase: A Target. The host javabase.
    """
    args = ctx.actions.args()
    args.add("--tool", "GENERATE_BINARY_R")
    args.add("--")
    args.add("--primaryRTxt", r_txt)
    args.add("--primaryManifest", manifest)
    args.add("--packageForR", package_for_r)
    args.add_all(
        resources_nodes,
        map_each = _make_generate_binay_r_flags,
        before_each = "--library",
    )
    if final_fields:
        args.add("--finalFields")
    else:
        args.add("--nofinalFields")

    # TODO(b/154003916): support transitive "--library transitive_r_txt_path,transitive_manifest_path" flags
    args.add("--classJarOutput", out_class_jar)
    args.add("--targetLabel", str(ctx.label))

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        arguments = [args],
        inputs = depset([r_txt, manifest], transitive = transitive_r_txts + transitive_manifests),
        outputs = [out_class_jar],
        mnemonic = "StarlarkRClassGenerator",
        progress_message = "Generating R classes",
    )

def _make_aar(
        ctx,
        out_aar = None,
        assets = [],
        assets_dir = None,
        resource_files = [],
        class_jar = None,
        r_txt = None,
        manifest = None,
        proguard_specs = [],
        should_throw_on_conflict = False,
        busybox = None,
        host_javabase = None):
    """Generate an android archive file.

    Args:
      ctx: The context.
      out_aar: File. The output AAR file.
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
      should_throw_on_conflict: A boolean. Determines whether an error should be thrown
        when a resource conflict occurs.
    """
    args = ctx.actions.args()
    args.add("--tool", "GENERATE_AAR")
    args.add("--")
    args.add(
        "--mainData",
        _make_resources_flag(
            manifest = manifest,
            assets = assets,
            assets_dir = assets_dir,
            resource_files = resource_files,
        ),
    )
    args.add("--manifest", manifest)
    args.add("--rtxt", r_txt)
    args.add("--classes", class_jar)
    args.add("--aarOutput", out_aar)
    args.add_all(proguard_specs, before_each = "--proguardSpec")
    if should_throw_on_conflict:
        args.add("--throwOnResourceConflict")

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = busybox,
        arguments = [args],
        inputs = (
            resource_files +
            assets +
            proguard_specs +
            [r_txt, manifest, class_jar]
        ),
        outputs = [out_aar],
        mnemonic = "StarlarkAARGenerator",
        progress_message = "Generating AAR package for %s" % ctx.label,
    )

busybox = struct(
    compile = _compile,
    merge_compiled = _merge_compiled,
    validate_and_link = _validate_and_link,
    merge_manifests = _merge_manifests,
    package = _package,
    parse = _parse,
    merge_assets = _merge_assets,
    make_resources_flag = _make_resources_flag,
    process_databinding = _process_databinding,
    generate_binary_r = _generate_binary_r,
    make_aar = _make_aar,

    # Exposed for testing
    mergee_manifests_flag = _mergee_manifests_flag,
    get_unique_res_dirs = _get_unique_res_dirs,
    sanitize_assets_dir = _sanitize_assets_dir,
    extract_filters = _extract_filters,
)
