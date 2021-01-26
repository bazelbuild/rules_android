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

load("@rules_android//rules:acls.bzl", "acls")
load("@rules_android//rules:attrs.bzl", _attrs = "attrs")
load("@rules_android//rules:common.bzl", _common = "common")
load("@rules_android//rules:data_binding.bzl", _data_binding = "data_binding")
load("@rules_android//rules:idl.bzl", _idl = "idl")
load("@rules_android//rules:intellij.bzl", _intellij = "intellij")
load("@rules_android//rules:java.bzl", _java = "java")
load(
    "@rules_android//rules:processing_pipeline.bzl",
    "ProviderInfo",
    "processing_pipeline",
)
load("@rules_android//rules:proguard.bzl", _proguard = "proguard")
load("@rules_android//rules:resources.bzl", _resources = "resources")
load("@rules_android//rules:utils.bzl", "get_android_sdk", "get_android_toolchain", "log", "utils")
load("@rules_android//rules/flags:flags.bzl", _flags = "flags")

_USES_DEPRECATED_IMPLICIT_EXPORT_ERROR = (
    "The android_library rule will be deprecating the use of deps to export " +
    "targets implicitly. " +
    "Please use android_library.exports to explicitly specify the exported " +
    "targets of %s."
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

def _uses_deprecated_implicit_export(ctx):
    if not ctx.attr.deps:
        return False
    return not (ctx.files.srcs or
                ctx.files.idl_srcs or
                ctx.attr._defined_assets or
                ctx.files.resource_files or
                ctx.attr.manifest)

def _uses_resources_and_deps_without_srcs(ctx):
    if not ctx.attr.deps:
        return False
    if not (ctx.attr._defined_assets or
            ctx.files.resource_files or
            ctx.attr.manifest):
        return False
    return not (ctx.files.srcs or ctx.files.idl_srcs)

def _check_deps_without_java_srcs(ctx):
    if not ctx.attr.deps or ctx.files.srcs or ctx.files.idl_srcs:
        return False
    gfn = getattr(ctx.attr, "generator_function", "")
    if _uses_deprecated_implicit_export(ctx):
        if (acls.in_android_library_implicit_exports_generator_functions(gfn) or
            acls.in_android_library_implicit_exports(str(ctx.label))):
            return True
        else:
            # TODO(b/144163743): add a test for this.
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

    return struct(
        enable_deps_without_srcs = _check_deps_without_java_srcs(ctx),
    )

def _exceptions_processor(ctx, **unused_ctxs):
    return ProviderInfo(
        name = "exceptions_ctx",
        value = _validate_rule_context(ctx),
    )

def _process_resources(ctx, java_package, **unused_ctxs):
    # exports_manifest can be overridden by a bazel flag.
    if ctx.attr.exports_manifest == _attrs.tristate.auto:
        exports_manifest = ctx.fragments.android.get_exports_manifest_default
    else:
        exports_manifest = ctx.attr.exports_manifest == _attrs.tristate.yes

    # Process Android Resources
    resources_ctx = _resources.process(
        ctx,
        manifest = ctx.file.manifest,
        resource_files = ctx.attr.resource_files,
        defined_assets = ctx.attr._defined_assets,
        assets = ctx.attr.assets,
        defined_assets_dir = ctx.attr._defined_assets_dir,
        assets_dir = ctx.attr.assets_dir,
        exports_manifest = exports_manifest,
        java_package = java_package,
        custom_package = ctx.attr.custom_package,
        neverlink = ctx.attr.neverlink,
        enable_data_binding = ctx.attr.enable_data_binding,
        deps = ctx.attr.deps,
        exports = ctx.attr.exports,

        # Processing behavior changing flags.
        enable_res_v3 = _flags.get(ctx).android_enable_res_v3,
        # TODO(b/144163743): remove fix_resource_transitivity, which was only added to emulate
        # misbehavior on the Java side.
        fix_resource_transitivity = bool(ctx.attr.srcs),
        fix_export_exporting = acls.in_fix_export_exporting_rollout(str(ctx.label)),
        android_test_migration = ctx.attr._android_test_migration,

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
            if AndroidResourcesInfo in src:
                log.error(_SRCS_CONTAIN_RESOURCE_LABEL_ERROR %
                          src[AndroidResourcesInfo].label)

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
            aidl_lib = get_android_sdk(ctx).aidl_lib,
            aidl_framework = get_android_sdk(ctx).framework_aidl,
        ),
    )

def _process_data_binding(ctx, java_package, resources_ctx, **unused_sub_ctxs):
    return ProviderInfo(
        name = "db_ctx",
        value = _data_binding.process(
            ctx,
            defines_resources = resources_ctx.defines_resources,
            enable_data_binding = ctx.attr.enable_data_binding,
            java_package = java_package,
            deps = utils.collect_providers(DataBindingV2Info, ctx.attr.deps),
            exports = utils.collect_providers(DataBindingV2Info, ctx.attr.exports),
            data_binding_exec = get_android_toolchain(ctx).data_binding_exec.files_to_run,
            data_binding_annotation_processor =
                get_android_toolchain(ctx).data_binding_annotation_processor[JavaInfo],
            data_binding_annotation_template =
                utils.only(get_android_toolchain(ctx).data_binding_annotation_template.files.to_list()),
        ),
    )

def _process_proguard(ctx, idl_ctx, **unused_sub_ctxs):
    return ProviderInfo(
        name = "proguard_ctx",
        value = _proguard.process(
            ctx,
            proguard_configs = ctx.files.proguard_specs,
            proguard_spec_providers = utils.collect_providers(
                ProguardSpecProvider,
                ctx.attr.deps,
                ctx.attr.exports,
                ctx.attr.plugins,
                ctx.attr.exported_plugins,
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
        plugins = (
            utils.collect_providers(JavaInfo, ctx.attr.plugins) +
            db_ctx.java_plugins
        ),
        exported_plugins = utils.collect_providers(
            JavaInfo,
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

def _process_aar(ctx, java_package, resources_ctx, proguard_ctx, **unused_ctx):
    aar_ctx = {
        _PROVIDERS: [],
        _VALIDATION_OUTPUTS: [],
    }

    starlark_aar = _resources.make_aar(
        ctx,
        manifest = resources_ctx.starlark_processed_manifest,
        assets = ctx.files.assets,
        assets_dir = ctx.attr.assets_dir,
        resource_files = resources_ctx.starlark_processed_resources if not ctx.attr.neverlink else [],
        class_jar = ctx.outputs.lib_jar,
        r_txt = resources_ctx.starlark_r_txt,
        proguard_specs = proguard_ctx.proguard_configs,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        host_javabase = _common.get_host_javabase(ctx),
    )

    # TODO(b/170409221): Clean this up once Starlark migration is complete. Create and propagate
    # a native aar info provider with the Starlark artifacts to avoid breaking downstream
    # targets.
    if not ctx.attr.neverlink:
        aar_ctx[_PROVIDERS].append(AndroidLibraryAarInfo(
            aar = starlark_aar,
            manifest = resources_ctx.starlark_processed_manifest,
            aars_from_deps = utils.collect_providers(
                AndroidLibraryAarInfo,
                ctx.attr.deps,
                ctx.attr.exports,
            ),
            defines_local_resources = resources_ctx.defines_resources,
        ))

    return ProviderInfo(
        name = "aar_ctx",
        value = _AARContextInfo(**aar_ctx),
    )

def _process_native(ctx, idl_ctx, **unused_ctx):
    return ProviderInfo(
        name = "native_ctx",
        value = struct(
            providers = [
                AndroidNativeLibsInfo(
                    depset(
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
                    cc_common.merge_cc_infos(
                        cc_infos = [
                                       info.cc_info
                                       for info in utils.collect_providers(
                                           JavaCcLinkParamsInfo,
                                           ctx.attr.deps,
                                           ctx.attr.exports,
                                           idl_ctx.idl_deps,
                                       )
                                   ] +
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

def _process_intellij(ctx, java_package, resources_ctx, idl_ctx, jvm_ctx, **unused_sub_ctxs):
    android_ide_info = _intellij.make_android_ide_info(
        ctx,
        java_package = java_package,
        manifest = ctx.file.manifest,
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
                    dependency_attributes = ["assets", "deps", "exports"],
                ),
            ],
        ),
    )

# Order dependent, as providers will not be available to downstream processors
# that may depend on the provider. Iteration order for a dictionary is based on
# insertion.
PROCESSORS = dict(
    ExceptionsProcessor = _exceptions_processor,
    ResourceProcessor = _process_resources,
    IdlProcessor = _process_idl,
    DataBindingProcessor = _process_data_binding,
    JvmProcessor = _process_jvm,
    ProguardProcessor = _process_proguard,
    AarProcessor = _process_aar,
    NativeProcessor = _process_native,
    IntelliJProcessor = _process_intellij,
    CoverageProcessor = _process_coverage,
)

# TODO(b/119560471): Deprecate the usage of legacy providers.
def _make_legacy_provider(intellij_ctx, jvm_ctx, providers):
    return struct(
        android = _intellij.make_legacy_android_provider(intellij_ctx.android_ide_info),
        java = struct(
            annotation_processing = jvm_ctx.java_info.annotation_processing,
            compilation_info = jvm_ctx.java_info.compilation_info,
            outputs = jvm_ctx.java_info.outputs,
            source_jars = depset(jvm_ctx.java_info.source_jars),
            transitive_deps = jvm_ctx.java_info.transitive_compile_time_jars,
            transitive_exports = jvm_ctx.java_info.transitive_exports,
            transitive_runtime_deps = jvm_ctx.java_info.transitive_runtime_jars,
            transitive_source_jars = jvm_ctx.java_info.transitive_source_jars,
        ),
        providers = providers,
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
    return _make_legacy_provider(intellij_ctx, jvm_ctx, providers)

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
