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

"""Implementation."""

load(
    "@rules_android//rules:acls.bzl",
    _acls = "acls",
)
load(
    "@rules_android//rules:common.bzl",
    _common = "common",
)
load("@rules_android//rules:intellij.bzl", "intellij")
load(
    "@rules_android//rules:java.bzl",
    _java = "java",
)
load("@rules_android//rules:providers.bzl", "AndroidLintRulesInfo")
load(
    "@rules_android//rules:resources.bzl",
    _resources = "resources",
)
load(
    "@rules_android//rules:utils.bzl",
    _get_android_toolchain = "get_android_toolchain",
    _utils = "utils",
)

RULE_PREFIX = "_aar"
ANDROID_MANIFEST = "AndroidManifest.xml"
LINT_JAR = "lint.jar"
_UNEXPECTED_LINT_JAR_ERROR = (
    "In target %s, has_lint_jar attribute is required when the aar contains " +
    "a lint.jar file."
)

def _create_aar_artifact(ctx, name):
    return ctx.actions.declare_file("%s/%s/%s" % (RULE_PREFIX, ctx.label.name, name))

def _create_aar_tree_artifact(ctx, name):
    return ctx.actions.declare_directory("%s/unzipped/%s/%s" % (RULE_PREFIX, name, ctx.label.name))

# Create an action to extract a file (specified by the parameter filename) from an AAR file.
def _extract_single_file(
        ctx,
        out_file,
        aar,
        filename,
        unzip_tool):
    args = ctx.actions.args()
    args.add(aar)
    args.add(filename)
    args.add("-d", out_file.dirname)

    ctx.actions.run(
        executable = unzip_tool,
        arguments = [args],
        inputs = [aar],
        outputs = [out_file],
        mnemonic = "AarFileExtractor",
        progress_message = "Extracting %s from %s" % (filename, aar.basename),
    )

def _extract_resources(
        ctx,
        out_resources_dir,
        out_assets_dir,
        aar,
        aar_resources_extractor_tool):
    args = ctx.actions.args()
    args.add("--input_aar", aar)
    args.add("--output_res_dir", out_resources_dir.path)
    args.add("--output_assets_dir", out_assets_dir.path)
    ctx.actions.run(
        executable = aar_resources_extractor_tool,
        arguments = [args],
        inputs = [aar],
        outputs = [out_resources_dir, out_assets_dir],
        mnemonic = "AarResourcesExtractor",
        progress_message = "Extracting resources and assets from %s" % aar.basename,
    )

def _extract_native_libs(
        ctx,
        output_zip,
        aar,
        android_cpu,
        aar_native_libs_zip_creator_tool):
    args = ctx.actions.args()
    args.add("--input_aar", aar)
    args.add("--cpu", android_cpu)
    args.add("--output_zip", output_zip)
    ctx.actions.run(
        executable = aar_native_libs_zip_creator_tool,
        arguments = [args],
        inputs = [aar],
        outputs = [output_zip],
        mnemonic = "AarNativeLibsFilter",
        progress_message = "Filtering AAR native libs by architecture",
    )

def _process_resources(
        ctx,
        aar,
        manifest,
        deps,
        aar_resources_extractor_tool,
        unzip_tool):
    # Extract resources and assets, if they exist.
    resources = _create_aar_tree_artifact(ctx, "resources")
    assets = _create_aar_tree_artifact(ctx, "assets")
    _extract_resources(
        ctx,
        resources,
        assets,
        aar,
        aar_resources_extractor_tool,
    )

    resources_ctx = _resources.process_starlark(
        ctx,
        manifest = manifest,
        assets = [assets],
        assets_dir = assets.path,
        resource_files = [resources],
        stamp_manifest = False,
        deps = ctx.attr.deps,
        exports = ctx.attr.exports,
        exports_manifest = getattr(ctx.attr, "exports_manifest", True),

        # Tool and Processing related inputs
        aapt = _get_android_toolchain(ctx).aapt2.files_to_run,
        android_jar = ctx.attr._android_sdk[AndroidSdkInfo].android_jar,
        android_kit = _get_android_toolchain(ctx).android_kit.files_to_run,
        busybox = _get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        java_toolchain = _common.get_java_toolchain(ctx),
        host_javabase = _common.get_host_javabase(ctx),
        instrument_xslt = _utils.only(_get_android_toolchain(ctx).add_g3itr_xslt.files.to_list()),
        xsltproc = _get_android_toolchain(ctx).xsltproc_tool.files_to_run,
    )

    # TODO: replace android_data
    # data_ctx = android_data.make_context(ctx.actions, ctx.attr)
    # resource_apk = android_data.process_aar_import_data(
    #     data_ctx,
    #     resources,
    #     assets,
    #     manifest,
    #     deps = deps,
    # )
    # resources_ctx["validation_results"].append(
    #     _utils.only(resource_apk[AndroidResourcesInfo].direct_android_resources.to_list()).java_class_jar,
    # )
    # resources_ctx["providers"].append(resource_apk[AndroidResourcesInfo])
    # resources_ctx["providers"].append(resource_apk[AndroidAssetsInfo])

    if not _acls.in_aar_propagate_resources(str(ctx.label)):
        resources_ctx["providers"] = []

    return struct(**resources_ctx)

def _extract_jars(
        ctx,
        out_jars_tree_artifact,
        out_jars_params_file,
        aar,
        aar_embedded_jars_extractor_tool):
    args = ctx.actions.args()
    args.add("--input_aar", aar)
    args.add("--output_dir", out_jars_tree_artifact.path)
    args.add("--output_singlejar_param_file", out_jars_params_file)
    ctx.actions.run(
        executable = aar_embedded_jars_extractor_tool,
        arguments = [args],
        inputs = [aar],
        outputs = [out_jars_tree_artifact, out_jars_params_file],
        mnemonic = "AarEmbeddedJarsExtractor",
        progress_message = "Extracting classes.jar and libs/*.jar from %s" % aar.basename,
    )

def _merge_jars(
        ctx,
        out_jar,
        jars_tree_artifact,
        jars_param_file,
        single_jar_tool):
    args = ctx.actions.args()
    args.add("--output", out_jar)
    args.add("--dont_change_compression")
    args.add("--normalize")
    args.add("@" + jars_param_file.path)
    ctx.actions.run(
        executable = single_jar_tool,
        arguments = [args],
        inputs = [jars_tree_artifact, jars_param_file],
        outputs = [out_jar],
        mnemonic = "AarJarsMerger",
        progress_message = "Merging AAR embedded jars",
    )

def _extract_and_merge_jars(
        ctx,
        out_jar,
        aar,
        aar_embedded_jars_extractor_tool,
        single_jar_tool):
    """Extracts all the Jars within the AAR and produces a single jar.

    An AAR may have multiple Jar files embedded within it. This method
    extracts and merges all Jars.
    """
    jars_tree_artifact = _create_aar_tree_artifact(ctx, "jars")
    jars_params_file = _create_aar_artifact(ctx, "jar_merging_params")
    _extract_jars(
        ctx,
        jars_tree_artifact,
        jars_params_file,
        aar,
        aar_embedded_jars_extractor_tool,
    )
    _merge_jars(
        ctx,
        out_jar,
        jars_tree_artifact,
        jars_params_file,
        single_jar_tool,
    )

def _create_import_deps_check(
        ctx,
        jars_to_check,
        declared_deps,
        transitive_deps,
        bootclasspath,
        jdeps_output,
        import_deps_checker_tool,
        host_javabase):
    args = ctx.actions.args()
    args.add_all(jars_to_check, before_each = "--input")
    args.add_all(declared_deps, before_each = "--directdep")
    args.add_all(transitive_deps, before_each = "--classpath_entry")
    args.add_all(bootclasspath, before_each = "--bootclasspath_entry")
    args.add("--checking_mode=error")
    args.add("--jdeps_output", jdeps_output)
    args.add("--rule_label", ctx.label)

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = import_deps_checker_tool,
        arguments = [args],
        inputs = depset(
            jars_to_check,
            transitive = [
                declared_deps,
                transitive_deps,
                bootclasspath,
            ],
        ),
        outputs = [jdeps_output],
        mnemonic = "ImportDepsChecker",
        progress_message = "Checking the completeness of the deps for %s" % jars_to_check,
    )

def _process_jars(
        ctx,
        out_jar,
        aar,
        source_jar,
        r_java,
        deps,
        exports,
        enable_desugar_java8,
        enable_imports_deps_check,
        bootclasspath,
        desugar_java8_extra_bootclasspath,
        aar_embedded_jars_extractor_tool,
        import_deps_checker_tool,
        single_jar_tool,
        java_toolchain,
        host_javabase):
    providers = []
    validation_results = []
    r_java_info = [r_java] if r_java else []

    # An aar may have multple Jar files, extract and merge into a single jar.
    _extract_and_merge_jars(
        ctx,
        out_jar,
        aar,
        aar_embedded_jars_extractor_tool,
        single_jar_tool,
    )

    java_infos = deps + exports

    if enable_desugar_java8:
        bootclasspath = depset(transitive = [
            desugar_java8_extra_bootclasspath,
            bootclasspath,
        ])

    merged_java_info = java_common.merge(java_infos + r_java_info)
    jdeps_artifact = _create_aar_artifact(ctx, "jdeps.proto")
    _create_import_deps_check(
        ctx,
        [out_jar],
        merged_java_info.compile_jars,
        merged_java_info.transitive_compile_time_jars,
        bootclasspath,
        jdeps_artifact,
        import_deps_checker_tool,
        host_javabase,
    )
    if enable_imports_deps_check:
        validation_results.append(jdeps_artifact)

    java_info = JavaInfo(
        out_jar,
        compile_jar = java_common.stamp_jar(
            actions = ctx.actions,
            jar = out_jar,
            target_label = ctx.label,
            java_toolchain = java_toolchain,
        ),
        source_jar = source_jar,
        neverlink = False,
        deps = r_java_info + java_infos,  # TODO(djwhang): Exports are not deps.
        exports =
            (r_java_info if _acls.in_aar_import_exports_r_java(str(ctx.label)) else []) +
            java_infos,  # TODO(djwhang): Deps are not exports.
        # TODO(djwhang): AarImportTest is not expecting jdeps, enable or remove it completely
        # jdeps = jdeps_artifact,
    )
    providers.append(java_info)

    return struct(
        java_info = java_info,
        providers = providers,
        validation_results = validation_results,
    )

def _validate_rule(
        ctx,
        aar,
        manifest,
        checks):
    package = _java.resolve_package_from_label(ctx.label, ctx.attr.package)
    validation_output = ctx.actions.declare_file("%s_validation_output" % ctx.label.name)

    args = ctx.actions.args()
    args.add("-aar", aar)
    inputs = [aar]
    args.add("-label", str(ctx.label))
    if _acls.in_aar_import_pkg_check(str(ctx.label)):
        args.add("-pkg", package)
        args.add("-manifest", manifest)
        inputs.append(manifest)
    if ctx.attr.has_lint_jar:
        args.add("-has_lint_jar")
    args.add("-output", validation_output)

    ctx.actions.run(
        executable = checks,
        arguments = [args],
        inputs = inputs,
        outputs = [validation_output],
        mnemonic = "ValidateAAR",
        progress_message = "Validating aar_import %s" % str(ctx.label),
    )
    return validation_output

def _process_lint_rules(
        ctx,
        aar,
        unzip_tool):
    providers = []

    if ctx.attr.has_lint_jar:
        lint_jar = _create_aar_artifact(ctx, LINT_JAR)
        _extract_single_file(
            ctx,
            lint_jar,
            aar,
            LINT_JAR,
            unzip_tool,
        )
        providers.append(AndroidLintRulesInfo(
            lint_jar = lint_jar,
        ))

    providers.extend(_utils.collect_providers(
        AndroidLintRulesInfo,
        ctx.attr.exports,
    ))
    return providers

def impl(ctx):
    """The rule implementation.

    Args:
      ctx: The context.

    Returns:
      A list of providers.
    """
    providers = []
    validation_outputs = []

    aar = _utils.only(ctx.files.aar)
    unzip_tool = _get_android_toolchain(ctx).unzip_tool.files_to_run

    # Extract the AndroidManifest.xml from the AAR.
    android_manifest = _create_aar_artifact(ctx, ANDROID_MANIFEST)
    _extract_single_file(
        ctx,
        android_manifest,
        aar,
        ANDROID_MANIFEST,
        unzip_tool,
    )

    resources_ctx = _process_resources(
        ctx,
        aar = aar,
        manifest = android_manifest,
        deps = ctx.attr.deps,
        aar_resources_extractor_tool =
            _get_android_toolchain(ctx).aar_resources_extractor.files_to_run,
        unzip_tool = unzip_tool,
    )
    providers.extend(resources_ctx.providers)

    merged_jar = _create_aar_artifact(ctx, "classes_and_libs_merged.jar")
    jvm_ctx = _process_jars(
        ctx,
        out_jar = merged_jar,
        aar = aar,
        source_jar = ctx.file.srcjar,
        deps = _utils.collect_providers(JavaInfo, ctx.attr.deps),
        r_java = resources_ctx.r_java,
        exports = _utils.collect_providers(JavaInfo, ctx.attr.exports),
        enable_desugar_java8 = ctx.fragments.android.desugar_java8,
        enable_imports_deps_check =
            _acls.in_aar_import_deps_checker(str(ctx.label)),
        aar_embedded_jars_extractor_tool =
            _get_android_toolchain(ctx).aar_embedded_jars_extractor.files_to_run,
        bootclasspath =
            ctx.attr._java_toolchain[java_common.JavaToolchainInfo].bootclasspath,
        desugar_java8_extra_bootclasspath =
            _get_android_toolchain(ctx).desugar_java8_extra_bootclasspath.files,
        import_deps_checker_tool =
            _get_android_toolchain(ctx).import_deps_checker.files_to_run,
        single_jar_tool =
            ctx.attr._java_toolchain[java_common.JavaToolchainInfo].single_jar,
        java_toolchain =
            ctx.attr._java_toolchain[java_common.JavaToolchainInfo],
        host_javabase = ctx.attr._host_javabase,
    )
    providers.extend(jvm_ctx.providers)
    validation_outputs.extend(jvm_ctx.validation_results)

    native_libs = _create_aar_artifact(ctx, "native_libs.zip")
    _extract_native_libs(
        ctx,
        native_libs,
        aar = aar,
        android_cpu = ctx.fragments.android.android_cpu,
        aar_native_libs_zip_creator_tool =
            _get_android_toolchain(ctx).aar_native_libs_zip_creator.files_to_run,
    )
    native_libs_infos = _utils.collect_providers(
        AndroidNativeLibsInfo,
        ctx.attr.deps,
        ctx.attr.exports,
    )
    providers.append(
        AndroidNativeLibsInfo(
            depset(
                [native_libs],
                transitive = [info.native_libs for info in native_libs_infos],
            ),
        ),
    )

    lint_providers = _process_lint_rules(
        ctx,
        aar = aar,
        unzip_tool = unzip_tool,
    )
    providers.extend(lint_providers)

    validation_outputs.append(_validate_rule(
        ctx,
        aar = aar,
        manifest = android_manifest,
        checks = _get_android_toolchain(ctx).aar_import_checks.files_to_run,
    ))

    providers.append(
        intellij.make_android_ide_info(
            ctx,
            java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.package),
            manifest = resources_ctx.merged_manifest,
            defines_resources = resources_ctx.defines_resources,
            merged_manifest = resources_ctx.merged_manifest,
            resources_apk = resources_ctx.resources_apk,
            r_jar = _utils.only(resources_ctx.r_java.outputs.jars) if resources_ctx.r_java else None,
            java_info = jvm_ctx.java_info,
            signed_apk = None,  # signed_apk, always empty for aar_import
            apks_under_test = [],  # apks_under_test, always empty for aar_import
            native_libs = dict(),  # nativelibs, always empty for aar_import
            idlclass = _get_android_toolchain(ctx).idlclass.files_to_run,
            host_javabase = _common.get_host_javabase(ctx),
        ),
    )

    providers.append(OutputGroupInfo(_validation = depset(validation_outputs)))

    # There isn't really any use case for building an aar_import target on its own, so the files to
    # build could be empty. The R class JAR and merged JARs are added here as a sanity check for
    # Bazel developers so that `bazel build java/com/my_aar_import` will fail if the resource
    # processing or JAR merging steps fail.
    files_to_build = []
    files_to_build.extend(resources_ctx.validation_results)  # TODO(djwhang): This should be validation.
    files_to_build.append(merged_jar)

    providers.append(
        DefaultInfo(
            files = depset(files_to_build),
            runfiles = ctx.runfiles(),
        ),
    )

    return providers
