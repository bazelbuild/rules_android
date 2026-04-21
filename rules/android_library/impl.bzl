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

load("//providers:providers.bzl", "AndroidCcLinkParamsInfo", "AndroidIdlInfo", "AndroidLibraryAarInfo", "AndroidLintRulesInfo", "AndroidNativeLibsInfo", "BaselineProfileProvider", "DataBindingV2Info", "StarlarkAndroidResourcesInfo", "StarlarkApkInfo")
load("//rules:acls.bzl", "acls")
load("//rules:attrs.bzl", _attrs = "attrs")
load("//rules:common.bzl", _common = "common")
load("//rules:data_binding.bzl", _data_binding = "data_binding")
load("//rules:idl.bzl", _idl = "idl")
load("//rules:intellij.bzl", _intellij = "intellij")
load("//rules:java.bzl", _java = "java")
load(
    "//rules:processing_pipeline.bzl",
    "ProviderInfo",
    "processing_pipeline",
)
load("//rules:proguard.bzl", _proguard = "proguard")
load("//rules:resources.bzl", _resources = "resources")
load("//rules:utils.bzl", "get_android_sdk", "get_android_toolchain", "log", "utils")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//rules/flags:flags.bzl", _flags = "flags")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@rules_java//java/common:java_plugin_info.bzl", "JavaPluginInfo")
load("@rules_java//java/common:proguard_spec_info.bzl", "ProguardSpecInfo")

visibility(PROJECT_VISIBILITY)

_USES_DEPRECATED_IMPLICIT_EXPORT_ERROR = (
    "Setting `deps` without `srcs` or `resource_files` is not supported. Consider using " +
    "`exports` to explicitly specify the exported targets of %s."
)

_SRCS_CONTAIN_RESOURCE_LABEL_ERROR = (
    "The srcs attribute of an android_library rule should not contain label " +
    "with resources %s"
)

_IDL_IMPORT_ROOT_SET_WITHOUT_SRCS_OR_PARCELABLES_ERROR = (
    "The 'idl_import_root' attribute of the android_library rule was set, " +
    "but neither 'idl_srcs' nor 'idl_parcelables' were specified."
)

_IDL_SRC_FROM_DIFFERENT_PACKAGE_ERROR = (
    "Do not import '%s' directly. You should either move the file to this " +
    "package or depend on an appropriate rule there."
)

_IDL_IDLOPTS_UNSUPPORTERD_ERROR = (
    "`idlopts` is supported only if `idl_uses_aosp_compiler` is set to true."
)

# Android library AAR context attributes.
_PROVIDERS = "providers"
_VALIDATION_OUTPUTS = "validation_outputs"

_AARContextInfo = provider(
    "Android library AAR context object",
    fields = {
        _PROVIDERS: "The list of all providers to propagate.",
        _VALIDATION_OUTPUTS: "List of outputs given to OutputGroupInfo _validation group",
    },
)

def _has_srcs(ctx):
    return ctx.files.srcs or ctx.files.idl_srcs or getattr(ctx.files, "common_srcs", False)

def _uses_deprecated_implicit_export(ctx):
    return (ctx.attr.deps and not (_has_srcs(ctx) or
                                   ctx.attr._defined_assets or
                                   ctx.files.resource_files or
                                   ctx.attr.manifest or
                                   ctx.attr.baseline_profiles))

def _uses_resources_and_deps_without_srcs(ctx):
    return (ctx.attr.deps and
            (ctx.attr._defined_assets or ctx.files.resource_files or ctx.attr.manifest) and
            not _has_srcs(ctx))

def _check_deps_without_java_srcs(ctx):
    if not ctx.attr.deps or _has_srcs(ctx):
        return False
    gfn = getattr(ctx.attr, "generator_function", "")
    if _uses_deprecated_implicit_export(ctx):
        log.error(_USES_DEPRECATED_IMPLICIT_EXPORT_ERROR % ctx.label)
    if _uses_resources_and_deps_without_srcs(ctx):
        if (acls.in_android_library_resources_without_srcs_generator_functions(gfn) or
            acls.in_android_library_resources_without_srcs(str(ctx.label))):
            return True
    return False

def _validate_rule_context(ctx):
    # Verify that idl_import_root is specified with idl_src or idl_parcelables.
    if (ctx.attr._defined_idl_import_root and
        not (ctx.attr._defined_idl_srcs or ctx.attr._defined_idl_parcelables)):
        log.error(_IDL_IMPORT_ROOT_SET_WITHOUT_SRCS_OR_PARCELABLES_ERROR)

    # Verify that idl_srcs are not from another package.
    for idl_src in ctx.attr.idl_srcs:
        if ctx.label.package != idl_src.label.package:
            log.error(_IDL_SRC_FROM_DIFFERENT_PACKAGE_ERROR % idl_src.label)

    # Check if idlopts is with idl_uses_aosp_compiler
    if ctx.attr.idlopts and not ctx.attr.idl_uses_aosp_compiler:
        log.error(_IDL_IDLOPTS_UNSUPPORTERD_ERROR)

    return struct(
        enable_deps_without_srcs = _check_deps_without_java_srcs(ctx),
    )

def _exceptions_processor(ctx, **unused_ctxs):
    return ProviderInfo(
        name = "exceptions_ctx",
        value = _validate_rule_context(ctx),
    )

def _process_manifest(ctx, **unused_ctxs):
    manifest_ctx = _resources.bump_min_sdk(
        ctx,
        manifest = ctx.file.manifest,
    )

    return ProviderInfo(
        name = "manifest_ctx",
        value = manifest_ctx,
    )

def _process_localized_resources(ctx, **unused_ctxs):
    return ProviderInfo(
        name = "localized_ctx",
        value = struct(
            resource_files = ctx.files.resource_files,
            providers = [],
        ),
    )

def _process_resources(ctx, java_package, manifest_ctx, localized_ctx, **unused_ctxs):
    # exports_manifest can be overridden by a bazel flag.
    if ctx.attr.exports_manifest == _attrs.tristate.auto:
        exports_manifest = ctx.fragments.android.get_exports_manifest_default
    else:
        exports_manifest = ctx.attr.exports_manifest == _attrs.tristate.yes

    resource_apks = []
    for apk in utils.collect_providers(StarlarkApkInfo, ctx.attr.resource_apks):
        resource_apks.append(apk.signed_apk)

    # Process Android Resources
    resources_ctx = _resources.process(
        ctx,
        manifest = manifest_ctx.processed_manifest,
        resource_files = localized_ctx.resource_files,
        defined_assets = ctx.attr._defined_assets,
        assets = ctx.files.assets,
        defined_assets_dir = ctx.attr._defined_assets_dir,
        assets_dir = ctx.attr.assets_dir,
        exports_manifest = exports_manifest,
        java_package = java_package,
        custom_package = ctx.attr.custom_package,
        neverlink = ctx.attr.neverlink,
        enable_data_binding = ctx.attr.enable_data_binding,
        deps = ctx.attr.deps,
        resource_apks = resource_apks,
        exports = ctx.attr.exports,
        feature_flags = acls.get_aapt2_feature_flags(str(ctx.label)),

        # Processing behavior changing flags.
        enable_res_v3 = _flags.get(ctx).android_enable_res_v3,
        # TODO(b/144163743): remove fix_resource_transitivity, which was only added to emulate
        # misbehavior on the Java side.
        fix_resource_transitivity = bool(ctx.attr.srcs),

        # Tool and Processing related inputs
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
        android_jar = get_android_sdk(ctx).android_jar,
        android_kit = get_android_toolchain(ctx).android_kit.files_to_run,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        java_toolchain = _common.get_java_toolchain(ctx),
        host_javabase = _common.get_host_javabase(ctx),
        instrument_xslt = utils.only(get_android_toolchain(ctx).add_g3itr_xslt.files.to_list()),
        res_v3_dummy_manifest = utils.only(
            get_android_toolchain(ctx).res_v3_dummy_manifest.files.to_list(),
        ),
        res_v3_dummy_r_txt = utils.only(
            get_android_toolchain(ctx).res_v3_dummy_r_txt.files.to_list(),
        ),
        xsltproc = get_android_toolchain(ctx).xsltproc_tool.files_to_run,
        zip_tool = get_android_toolchain(ctx).zip_tool.files_to_run,
    )

    # TODO(b/139305816): Remove the ability for android_library to be added in
    # the srcs attribute of another android_library.
    if resources_ctx.defines_resources:
        # Verify that srcs do no contain labels.
        for src in ctx.attr.srcs:
            if StarlarkAndroidResourcesInfo in src:
                log.error(_SRCS_CONTAIN_RESOURCE_LABEL_ERROR % src.label)

    return ProviderInfo(
        name = "resources_ctx",
        value = resources_ctx,
    )

def _process_idl(ctx, **unused_sub_ctxs):
    return ProviderInfo(
        name = "idl_ctx",
        value = _idl.process(
            ctx,
            idl_srcs = ctx.files.idl_srcs,
            idl_parcelables = ctx.files.idl_parcelables,
            idl_import_root =
                ctx.attr.idl_import_root if ctx.attr._defined_idl_import_root else None,
            idl_preprocessed = ctx.files.idl_preprocessed,
            deps = utils.collect_providers(AndroidIdlInfo, ctx.attr.deps),
            exports = utils.collect_providers(AndroidIdlInfo, ctx.attr.exports),
            aidl = get_android_sdk(ctx).aidl,
            aidl_lib = ctx.attr._aidl_lib,
            aidl_framework = get_android_sdk(ctx).framework_aidl,
            uses_aosp_compiler = ctx.attr.idl_uses_aosp_compiler,
            idlopts = ctx.attr.idlopts,
        ),
    )

def _process_data_binding(ctx, java_package, resources_ctx, **unused_sub_ctxs):
    if ctx.attr.enable_data_binding and not acls.in_databinding_allowed(str(ctx.label)):
        fail("This target is not allowed to use databinding and enable_data_binding is True.")

    if ctx.attr._databinding_use_androidx[BuildSettingInfo].value:
        template = get_android_toolchain(ctx).data_binding_annotation_template_androidx
    else:
        template = get_android_toolchain(ctx).data_binding_annotation_template_support_lib
    data_binding_annotation_template = utils.only(template.files.to_list())

    return ProviderInfo(
        name = "db_ctx",
        value = _data_binding.process(
            ctx,
            defines_resources = resources_ctx.defines_resources,
            enable_data_binding = ctx.attr.enable_data_binding,
            java_package = java_package,
            layout_info = resources_ctx.data_binding_layout_info,
            deps = utils.collect_providers(DataBindingV2Info, ctx.attr.deps),
            exports = utils.collect_providers(DataBindingV2Info, ctx.attr.exports),
            data_binding_exec = get_android_toolchain(ctx).data_binding_exec.files_to_run,
            data_binding_annotation_processor =
                get_android_toolchain(ctx).data_binding_annotation_processor,
            data_binding_annotation_template = data_binding_annotation_template,
        ),
    )

def _process_proguard(ctx, idl_ctx, **unused_sub_ctxs):
    return ProviderInfo(
        name = "proguard_ctx",
        value = _proguard.process_specs(
            ctx,
            proguard_configs = ctx.files.proguard_specs,
            proguard_spec_providers = utils.collect_providers(
                ProguardSpecInfo,
                ctx.attr.deps,
                ctx.attr.exports,
                idl_ctx.idl_deps,
            ),
            proguard_allowlister =
                get_android_toolchain(ctx).proguard_allowlister.files_to_run,
        ),
    )

def _process_jvm(ctx, exceptions_ctx, resources_ctx, idl_ctx, db_ctx, **unused_sub_ctxs):
    java_info = _java.compile_android(
        ctx,
        ctx.outputs.lib_jar,
        ctx.outputs.lib_src_jar,
        srcs = ctx.files.srcs + idl_ctx.idl_java_srcs + db_ctx.java_srcs,
        javac_opts = ctx.attr.javacopts + db_ctx.javac_opts,
        r_java = resources_ctx.r_java,
        deps =
            utils.collect_providers(JavaInfo, ctx.attr.deps, idl_ctx.idl_deps),
        exports = utils.collect_providers(JavaInfo, ctx.attr.exports),
        plugins = utils.collect_providers(JavaPluginInfo, ctx.attr.plugins, db_ctx.java_plugins),
        exported_plugins = utils.collect_providers(
            JavaPluginInfo,
            ctx.attr.exported_plugins,
        ),
        annotation_processor_additional_outputs = (
            db_ctx.java_annotation_processor_additional_outputs
        ),
        annotation_processor_additional_inputs = (
            db_ctx.java_annotation_processor_additional_inputs
        ),
        enable_deps_without_srcs = exceptions_ctx.enable_deps_without_srcs,
        neverlink = ctx.attr.neverlink,
        strict_deps = "DEFAULT",
        java_toolchain = _common.get_java_toolchain(ctx),
    )

    return ProviderInfo(
        name = "jvm_ctx",
        value = struct(
            java_info = java_info,
            providers = [java_info],
        ),
    )

def _process_lint_rules(ctx, **unused_sub_ctxs):
    providers = []
    if acls.in_enable_exported_lint_checks(str(ctx.label)):
        # Propagate Lint rule Jars from any exported AARs (b/229993446)
        android_lint_rules = [info.lint_jars for info in utils.collect_providers(
            AndroidLintRulesInfo,
            ctx.attr.exports,
        )]
        if android_lint_rules:
            providers.append(
                AndroidLintRulesInfo(
                    lint_jars = depset(transitive = android_lint_rules),
                ),
            )
    return ProviderInfo(
        name = "lint_rules_ctx",
        value = struct(
            providers = providers,
        ),
    )

def _process_aar(ctx, java_package, resources_ctx, proguard_ctx, **unused_ctx):
    aar_ctx = {
        _PROVIDERS: [],
        _VALIDATION_OUTPUTS: [],
    }

    # This is a workaround to fix b/445511343 that translation resources are missing in the final
    # aar for the internal version of android_library. The workaround doesn't work with data binding
    # enabled. Given we've deprecated data binding internally, this is an acceptable compromise.
    if ctx.attr.neverlink:
        resource_files = []
    elif resources_ctx.data_binding_layout_info:
        resource_files = resources_ctx.starlark_processed_resources
    else:
        resource_files = ctx.files.resource_files

    starlark_aar = _resources.make_aar(
        ctx,
        manifest = resources_ctx.starlark_processed_manifest,
        assets = ctx.files.assets,
        assets_dir = ctx.attr.assets_dir,
        resource_files = resource_files,
        class_jar = ctx.outputs.lib_jar,
        r_txt = resources_ctx.starlark_r_txt,
        aar_metadata = ctx.file.aar_metadata,
        proguard_specs = proguard_ctx.proguard_configs,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )

    if not ctx.attr.neverlink:
        aar_ctx[_PROVIDERS].append(AndroidLibraryAarInfo(
            aar = starlark_aar if resources_ctx.defines_resources else None,
        ))

    return ProviderInfo(
        name = "aar_ctx",
        value = _AARContextInfo(**aar_ctx),
    )

def _get_cc_link_params_infos(ctx, idl_ctx):
    infos = []
    for info in utils.collect_providers(JavaInfo, ctx.attr.deps, ctx.attr.exports, idl_ctx.idl_deps):
        if getattr(info, "cc_link_params_info", None):
            infos.append(info.cc_link_params_info)
        else:
            # cc_link_params_info attr not available without --experimental_google_legacy_api
            infos.append(
                CcInfo(
                    compilation_context = None,
                    linking_context = cc_common.create_linking_context(
                        linker_inputs = depset([
                            cc_common.create_linker_input(
                                owner = ctx.label,
                                libraries = info.transitive_native_libraries,
                            ),
                        ]),
                    ),
                ),
            )

    return infos

def _process_native(ctx, idl_ctx, **unused_ctx):
    return ProviderInfo(
        name = "native_ctx",
        value = struct(
            providers = [
                AndroidNativeLibsInfo(
                    native_libs = depset(
                        transitive = [
                            p.native_libs
                            for p in utils.collect_providers(
                                AndroidNativeLibsInfo,
                                ctx.attr.deps,
                                ctx.attr.exports,
                            )
                        ],
                        order = "preorder",
                    ),
                ),
                AndroidCcLinkParamsInfo(
                    link_params = cc_common.merge_cc_infos(
                        cc_infos = _get_cc_link_params_infos(ctx, idl_ctx) +
                                   [
                                       info.link_params
                                       for info in utils.collect_providers(
                                           AndroidCcLinkParamsInfo,
                                           ctx.attr.deps,
                                           ctx.attr.exports,
                                           idl_ctx.idl_deps,
                                       )
                                   ] +
                                   utils.collect_providers(
                                       CcInfo,
                                       ctx.attr.deps,
                                       ctx.attr.exports,
                                       idl_ctx.idl_deps,
                                   ),
                    ),
                ),
            ],
        ),
    )

def _process_intellij(ctx, java_package, manifest_ctx, resources_ctx, idl_ctx, jvm_ctx, **unused_sub_ctxs):
    android_ide_info = _intellij.make_android_ide_info(
        ctx,
        java_package = java_package,
        manifest = manifest_ctx.processed_manifest,
        defines_resources = resources_ctx.defines_resources,
        merged_manifest = resources_ctx.merged_manifest,
        resources_apk = resources_ctx.resources_apk,
        r_jar = utils.only(resources_ctx.r_java.outputs.jars) if resources_ctx.r_java else None,
        idl_import_root = idl_ctx.idl_import_root,
        idl_srcs = idl_ctx.idl_srcs,
        idl_java_srcs = idl_ctx.idl_java_srcs,
        java_info = jvm_ctx.java_info,
        signed_apk = None,  # signed_apk, always empty for android_library.
        aar = getattr(ctx.outputs, "aar", None),  # Deprecate aar for android_library.
        apks_under_test = [],  # apks_under_test, always empty for android_library
        native_libs = dict(),  # nativelibs, always empty for android_library
        idlclass = get_android_toolchain(ctx).idlclass.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )
    return ProviderInfo(
        name = "intellij_ctx",
        value = struct(
            android_ide_info = android_ide_info,
            providers = [android_ide_info],
        ),
    )

def _process_coverage(ctx, **unused_ctx):
    return ProviderInfo(
        name = "coverage_ctx",
        value = struct(
            providers = [
                coverage_common.instrumented_files_info(
                    ctx,
                    source_attributes = ["srcs"],
                    # NOTE: Associates is only applicable for OSS rules_kotlin.
                    dependency_attributes = ["associates", "assets", "deps", "exports"],
                ),
            ],
        ),
    )

def _process_baseline_profiles(ctx, **unused_ctx):
    return ProviderInfo(
        name = "bp_ctx",
        value = struct(
            providers = [
                BaselineProfileProvider(files = depset(
                    ctx.files.baseline_profiles,
                    transitive = [bp.files for bp in utils.collect_providers(BaselineProfileProvider, ctx.attr.deps, ctx.attr.exports)],
                )),
            ],
        ),
    )

# Order dependent, as providers will not be available to downstream processors
# that may depend on the provider. Iteration order for a dictionary is based on
# insertion.
PROCESSORS = dict(
    ExceptionsProcessor = _exceptions_processor,
    LintRulesProcessor = _process_lint_rules,
    ManifestProcessor = _process_manifest,
    LocalizedResourcesProcessor = _process_localized_resources,
    ResourceProcessor = _process_resources,
    IdlProcessor = _process_idl,
    DataBindingProcessor = _process_data_binding,
    JvmProcessor = _process_jvm,
    ProguardProcessor = _process_proguard,
    AarProcessor = _process_aar,
    NativeProcessor = _process_native,
    IntelliJProcessor = _process_intellij,
    CoverageProcessor = _process_coverage,
    BaselineProfilesProcessor = _process_baseline_profiles,
)

def finalize(
        ctx,
        resources_ctx,
        intellij_ctx,
        jvm_ctx,
        proguard_ctx,
        providers,
        validation_outputs,
        **unused_ctxs):
    """Creates the DefaultInfo and OutputGroupInfo providers.

    Args:
      ctx: The context.
      resources_ctx: ProviderInfo. The resources ctx.
      intellij_ctx: ProviderInfo. The intellij ctx.
      jvm_ctx: ProviderInfo. The jvm ctx.
      proguard_ctx: ProviderInfo. The proguard ctx.
      providers: sequence of providers. The providers to propagate.
      validation_outputs: sequence of Files. The validation outputs.
      **unused_ctxs: Unused ProviderInfo.

    Returns:
      A struct with Android and Java legacy providers and a list of providers.
    """
    transitive_runfiles = []
    if not ctx.attr.neverlink:
        for p in utils.collect_providers(
            DefaultInfo,
            ctx.attr.deps,
            ctx.attr.exports,
        ):
            transitive_runfiles.append(p.data_runfiles.files)
            transitive_runfiles.append(p.default_runfiles.files)
    runfiles = ctx.runfiles(
        files = (
            (resources_ctx.r_java.runtime_output_jars if resources_ctx.r_java and not ctx.attr.neverlink else []) +
            ([ctx.outputs.lib_jar] if (ctx.attr.srcs or ctx.attr.idl_srcs) and not ctx.attr.neverlink else [])
        ),
        transitive_files = depset(transitive = transitive_runfiles),
        collect_default = True,
    )
    files = [ctx.outputs.lib_jar]
    if getattr(ctx.outputs, "resources_src_jar", None):
        files.append(ctx.outputs.resources_src_jar)
    if getattr(ctx.outputs, "resources_jar", None):
        files.append(ctx.outputs.resources_jar)

    providers.extend([
        DefaultInfo(
            files = depset(files),
            runfiles = runfiles,
        ),
        OutputGroupInfo(
            compilation_outputs = depset([ctx.outputs.lib_jar]),
            _source_jars = depset(
                [ctx.outputs.lib_src_jar],
                transitive = [jvm_ctx.java_info.transitive_source_jars],
            ),
            _direct_source_jars = depset([ctx.outputs.lib_src_jar]),
            _hidden_top_level_INTERNAL_ = depset(
                resources_ctx.validation_results,
                transitive = [
                    info._hidden_top_level_INTERNAL_
                    for info in utils.collect_providers(
                        OutputGroupInfo,
                        ctx.attr.deps,
                        ctx.attr.exports,
                    )
                ] + [proguard_ctx.transitive_proguard_configs],
            ),
            _validation = depset(validation_outputs),
        ),
    ])
    return providers

_PROCESSING_PIPELINE = processing_pipeline.make_processing_pipeline(
    processors = PROCESSORS,
    finalize = finalize,
)

def impl(ctx):
    """The rule implementation.

    Args:
      ctx: The context.

    Returns:
      A legacy struct provider.
    """
    java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package)
    return processing_pipeline.run(ctx, java_package, _PROCESSING_PIPELINE)
