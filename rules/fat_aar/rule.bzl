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

"""fat_aar rule implementation."""

load("@rules_java//java/common:java_common.bzl", "java_common")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_java//java/common:proguard_spec_info.bzl", "ProguardSpecInfo")
load("//rules:busybox.bzl", _busybox = "busybox")
load("//rules:common.bzl", _common = "common")
load("//rules:java.bzl", "java")
load("//rules:providers.bzl", "AndroidAssetsInfo", "AndroidNativeLibsInfo", "AndroidResourcesInfo", "StarlarkAndroidResourcesInfo")
load("//rules:resources.bzl", _resources = "resources")
load("//rules:utils.bzl", "get_android_sdk", "get_android_toolchain", "utils")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//rules/fat_aar:aspect.bzl", "FatAarDependenciesInfo", "FatAarInfo", "fat_aar_aspect")

visibility(PROJECT_VISIBILITY)

def _fat_aar_impl(ctx):
    """Bundles transitive android_library deps into a single AAR.

    When working with modular Android projects, publishing individual libraries can become
    unwieldy as the number of modules grows. The fat_aar rule consolidates multiple internal
    android_library targets into a unified AAR package, providing several advantages:

    - Dependency management: Consumers depend on a single AAR instead of managing multiple
      library versions, reducing integration complexity
    - Size optimization: Bundling libraries together can enable better code shrinking and
      result in a more compact final artifact
    - Encapsulation: Internal module structure remains hidden, giving library authors greater
      flexibility to refactor without impacting external consumers

    Args:
      ctx: The context.

    Returns:
      A list of providers.
    """

    # Collect and merge JavaInfo providers
    all_java_infos = utils.collect_providers(JavaInfo, ctx.attr.deps)
    merged_java_info = java_common.merge(all_java_infos)

    # Helper function to check if label or file should be excluded
    def should_exclude_label(label):
        label_str = str(label)
        for exclude_pattern in ctx.attr.exclude:
            if exclude_pattern in label_str:
                return True
        return False

    def should_exclude_file(file):
        # Check file path for external repo markers
        if not hasattr(file, "path"):
            return False
        path = file.path
        for exclude_pattern in ctx.attr.exclude:
            # Fast check: external files have paths like "external/maven/..."
            if exclude_pattern.startswith("@"):
                # Strip all leading @ (handles both @repo and @@repo bzlmod syntax)
                repo_name = exclude_pattern.lstrip("@").rstrip("/")
                # WORKSPACE format: external/<repo_name>/
                if "external/" + repo_name + "/" in path:
                    return True
                # Old bzlmod format: ~<repo_name>/
                if "~" + repo_name + "/" in path:
                    return True
                # Bzlmod canonical format: +<module>+<repo_name>/ (e.g. +maven_repos+maven/)
                if "+" + repo_name + "/" in path:
                    return True
        return False

    # Collect Android providers from aspect (now as (label, provider) tuples)
    # Track excluded labels for POM generation
    all_resource_infos = []
    all_assets_infos = []
    all_native_libs_infos = []
    all_manifest_infos = []
    all_proguard_infos = []
    excluded_labels = []

    for dep in ctx.attr.deps:
        if FatAarInfo not in dep:
            continue
        # Filter based on exclude patterns
        for label, info in dep[FatAarInfo].resource_infos.to_list():
            if should_exclude_label(label):
                excluded_labels.append(label)
            else:
                all_resource_infos.append(info)
        for label, info in dep[FatAarInfo].assets_infos.to_list():
            if should_exclude_label(label):
                excluded_labels.append(label)
            else:
                all_assets_infos.append(info)
        for label, info in dep[FatAarInfo].native_libs_infos.to_list():
            if should_exclude_label(label):
                excluded_labels.append(label)
            else:
                all_native_libs_infos.append(info)
        for label, manifest in dep[FatAarInfo].manifest_infos.to_list():
            if should_exclude_label(label):
                excluded_labels.append(label)
            else:
                all_manifest_infos.append(manifest)
        for label, info in dep[FatAarInfo].proguard_infos.to_list():
            if should_exclude_label(label):
                excluded_labels.append(label)
            else:
                all_proguard_infos.append(info)

    # Extract transitive data from collected providers
    # Handle both AndroidResourcesInfo and StarlarkAndroidResourcesInfo
    transitive_resource_files = []
    transitive_assets = []
    transitive_manifests = []
    transitive_r_txts = []

    for info in all_resource_infos:
        if type(info) == "StarlarkAndroidResourcesInfo" or hasattr(info, "transitive_resource_files"):
            transitive_resource_files.append(info.transitive_resource_files)
            transitive_manifests.append(info.transitive_manifests)
            transitive_r_txts.append(info.transitive_r_txts)
            if hasattr(info, "transitive_assets"):
                transitive_assets.append(info.transitive_assets)
        elif hasattr(info, "transitive_resources"):
            transitive_resource_files.append(info.transitive_resources)
            transitive_manifests.append(info.transitive_manifests)
            transitive_r_txts.append(info.transitive_aapt2_r_txt)

    for info in all_assets_infos:
        transitive_assets.append(info.assets)

    # Use depset filtering - only convert to list at the end if needed
    if ctx.attr.exclude:
        # Filter files lazily
        all_resource_files = depset(transitive = transitive_resource_files).to_list()
        resource_files = [f for f in all_resource_files if not should_exclude_file(f)]

        all_assets = depset(transitive = transitive_assets).to_list()
        assets = [f for f in all_assets if not should_exclude_file(f)]

        all_manifests_from_providers = depset(transitive = transitive_manifests).to_list()
        filtered_manifests = [f for f in all_manifests_from_providers if not should_exclude_file(f)]
        manifests = filtered_manifests + all_manifest_infos

        all_r_txts = depset(transitive = transitive_r_txts).to_list()
        r_txts = [f for f in all_r_txts if not should_exclude_file(f)]
    else:
        # No filtering - use depsets directly
        resource_files = depset(transitive = transitive_resource_files).to_list()
        assets = depset(transitive = transitive_assets).to_list()
        manifests = depset(transitive = transitive_manifests).to_list() + all_manifest_infos
        r_txts = depset(transitive = transitive_r_txts).to_list()

    assets_dir = "assets" if assets else None

    # Merge transitive manifests
    merged_manifest = ctx.actions.declare_file(ctx.label.name + "_merged/AndroidManifest.xml")

    if not manifests:
        ctx.actions.write(
            merged_manifest,
            content = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.bundled.library">
</manifest>
""",
        )
    elif len(manifests) == 1:
        ctx.actions.run_shell(
            inputs = manifests,
            outputs = [merged_manifest],
            command = "cp $1 $2",
            arguments = [manifests[0].path, merged_manifest.path],
            mnemonic = "CopyManifest",
        )
    else:
        primary_manifest = ctx.actions.declare_file(ctx.label.name + "_primary/AndroidManifest.xml")
        ctx.actions.write(
            primary_manifest,
            content = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    package="com.bundled.library">
    <uses-sdk android:minSdkVersion="{min_sdk}" />
    <application />
</manifest>
""".format(min_sdk = ctx.attr.min_sdk_version),
        )

        merge_log = ctx.actions.declare_file(ctx.label.name + "_merged/manifest_merger_log.txt")

        # Use APPLICATION merge type (same as android_binary)
        _busybox.merge_manifests(
            ctx,
            out_file = merged_manifest,
            out_log_file = merge_log,
            merge_type = "APPLICATION",
            manifest = primary_manifest,
            mergee_manifests = depset(manifests),
            manifest_merge_order = "dependency",
            manifest_values = {},
            java_package = None,
            busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
            host_javabase = _common.get_host_javabase(ctx),
        )

    # Merge transitive runtime JARs into single classes.jar
    # Filter out excluded dependencies (e.g., external Maven dependencies)
    merged_class_jar = ctx.actions.declare_file(ctx.label.name + "_classes.jar")

    all_jars = merged_java_info.transitive_runtime_jars.to_list()
    filtered_jars = []

    for jar in all_jars:
        # Check if jar should be excluded based on exclude patterns
        owner_str = str(jar.owner) if jar.owner else ""
        should_exclude = False
        for exclude_pattern in ctx.attr.exclude:
            if exclude_pattern in owner_str:
                should_exclude = True
                excluded_labels.append(jar.owner)
                break
        if should_exclude:
            continue
        filtered_jars.append(jar)

    args = ctx.actions.args()
    args.add("--output", merged_class_jar)
    args.add("--dont_change_compression")
    args.add("--normalize")

    for jar in filtered_jars:
        args.add("--sources", jar)

    java_toolchain = _common.get_java_toolchain(ctx)
    ctx.actions.run(
        executable = java_toolchain[java_common.JavaToolchainInfo].single_jar,
        arguments = [args],
        inputs = depset(filtered_jars),
        outputs = [merged_class_jar],
        mnemonic = "MergeLibraryJars",
        progress_message = "Merging transitive library jars",
    )

    r_txt = r_txts[0] if r_txts else None
    if not r_txt:
        r_txt = ctx.actions.declare_file(ctx.label.name + "_R.txt")
        ctx.actions.write(r_txt, content = "")

    proguard_specs = []
    for spec_info in all_proguard_infos:
        all_specs = spec_info.specs.to_list()
        proguard_specs.extend([s for s in all_specs if not should_exclude_file(s)])

    # Run R8 optimization if r8_config is provided
    if ctx.file.r8_config:
        class_jar = ctx.actions.declare_file(ctx.label.name + "_optimized_classes.jar")

        # Collect all ProGuard configs: user-provided + transitive deps
        all_proguard_configs = [ctx.file.r8_config] + proguard_specs

        # Get android_jar from SDK (same as android_binary)
        android_jar = get_android_sdk(ctx).android_jar

        # R8 command line arguments
        # Use --classfile to output .class files instead of .dex
        # Note: --min-api is not supported with --classfile
        r8_args = ctx.actions.args()
        r8_args.add("--classfile")
        r8_args.add("--lib", android_jar)
        r8_args.add("--release")
        r8_args.add("--output", class_jar)

        # Add all ProGuard config files
        for config in all_proguard_configs:
            r8_args.add("--pg-conf", config)

        r8_args.add(merged_class_jar)

        java.run(
            ctx = ctx,
            host_javabase = _common.get_host_javabase(ctx),
            executable = get_android_toolchain(ctx).r8.files_to_run,
            arguments = [r8_args],
            inputs = [merged_class_jar, android_jar] + all_proguard_configs,
            outputs = [class_jar],
            mnemonic = "R8Optimize",
            progress_message = "Optimizing classes with R8",
        )
    else:
        class_jar = merged_class_jar

    fat_aar_java_info = JavaInfo(
        output_jar = class_jar,
        compile_jar = class_jar,
        deps = all_java_infos,
    )

    all_native_libs = []
    for info in all_native_libs_infos:
        all_native_libs.extend(info.native_libs.to_list())
    native_libs_files = [f for f in all_native_libs if not should_exclude_file(f)]

    aar = ctx.actions.declare_file(ctx.label.name + ".aar")
    if native_libs_files:
        # Create base AAR then add native libs via script
        base_aar = ctx.actions.declare_file(ctx.label.name + "_base.aar")
        _busybox.make_aar(
            ctx,
            out_aar = base_aar,
            assets = assets,
            assets_dir = assets_dir,
            resource_files = resource_files,
            class_jar = class_jar,
            r_txt = r_txt,
            manifest = merged_manifest,
            proguard_specs = proguard_specs,
            busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
            host_javabase = _common.get_host_javabase(ctx),
        )

        temp_dir = ctx.actions.declare_directory(ctx.label.name + "_temp_native_libs")

        args = ctx.actions.args()
        args.add(base_aar)
        args.add(aar)
        args.add(temp_dir.path)
        args.add_all(native_libs_files)

        ctx.actions.run_shell(
            inputs = [base_aar, ctx.file._add_native_libs_script] + native_libs_files,
            outputs = [aar, temp_dir],
            command = "bash $1 ${@:2}",
            arguments = [ctx.file._add_native_libs_script.path, args],
            mnemonic = "AddNativeLibsToAAR",
            progress_message = "Adding native libraries to AAR",
        )
    else:
        aar = _resources.make_aar(
            ctx,
            assets = assets,
            assets_dir = assets_dir,
            resource_files = resource_files,
            class_jar = class_jar,
            r_txt = r_txt,
            manifest = merged_manifest,
            proguard_specs = proguard_specs,
            busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
            host_javabase = _common.get_host_javabase(ctx),
        )

    # Generate excluded dependencies file
    # Just output the raw excluded labels - consumers can filter/transform as needed
    excluded_deps_file = ctx.actions.declare_file(ctx.label.name + "_excluded_deps.txt")

    # Deduplicate labels
    unique_labels = {}
    for label in excluded_labels:
        label_str = str(label)
        if label_str not in unique_labels:
            unique_labels[label_str] = True

    content = ""
    for label_str in sorted(unique_labels.keys()):
        content += label_str + "\n"

    ctx.actions.write(
        output = excluded_deps_file,
        content = content,
    )

    return [
        DefaultInfo(
            files = depset([aar]),
        ),
        OutputGroupInfo(
            aar = depset([aar]),
            class_jar = depset([class_jar]),
            manifest = depset([merged_manifest]),
            excluded_deps = depset([excluded_deps_file]),
        ),
        fat_aar_java_info,
        StarlarkAndroidResourcesInfo(
            direct_resources_nodes = depset(),
            transitive_resources_nodes = depset(),
            transitive_assets = depset(assets),
            transitive_assets_symbols = depset(),
            transitive_compiled_assets = depset(),
            direct_compiled_resources = depset(),
            transitive_compiled_resources = depset(),
            transitive_manifests = depset([merged_manifest]),
            transitive_r_txts = depset([r_txt]),
            transitive_resource_files = depset(resource_files),
            packages_to_r_txts = {},
            transitive_resource_apks = depset(),
        ),
        AndroidNativeLibsInfo(
            native_libs = depset(native_libs_files),
        ),
        FatAarDependenciesInfo(
            excluded_labels = depset(excluded_labels),
        ),
    ]

fat_aar = rule(
    implementation = _fat_aar_impl,
    attrs = {
        "deps": attr.label_list(
            aspects = [fat_aar_aspect],
            doc = "The list of android_library targets to bundle",
        ),
        "min_sdk_version": attr.string(
            default = "23",
            doc = "Minimum SDK version for the primary manifest",
        ),
        "exclude": attr.string_list(
            default = [],
            doc = "List of patterns to exclude from bundling (e.g., ['@maven//'])",
        ),
        "r8_config": attr.label(
            allow_single_file = [".pro", ".txt"],
            doc = "ProGuard configuration file for R8. If provided, R8 optimization is enabled. Combined with transitive ProGuard specs from dependencies.",
        ),
        "_add_native_libs_script": attr.label(
            default = Label("//rules/fat_aar:add_native_libs.sh"),
            allow_single_file = True,
        ),
        "_java_toolchain": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_java_toolchain"),
        ),
        "_host_javabase": attr.label(
            default = Label("@bazel_tools//tools/jdk:current_host_java_runtime"),
            cfg = "exec",
        ),
    },
    toolchains = [
        config_common.toolchain_type("@rules_android//toolchains/android:toolchain_type", mandatory = False),
        config_common.toolchain_type("//toolchains/android:toolchain_type", mandatory = False),
        config_common.toolchain_type("@rules_android//toolchains/android_sdk:toolchain_type", mandatory = False),
        config_common.toolchain_type("//toolchains/android_sdk:toolchain_type", mandatory = False),
    ],
    fragments = ["android", "bazel_android", "java"],
    doc = "Bundles transitive android_library dependencies into a single AAR file.",
)
