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

"""Bazel rule for building an APK."""

load("//rules:acls.bzl", "acls")
load("//rules:android_platforms_transition.bzl", "android_platforms_transition")
load("//rules:attrs.bzl", _attrs = "attrs")
load(
    "//rules/android_binary_internal:attrs.bzl",
    _BASE_ATTRS = "ATTRS",
)
load(
    "//rules/android_binary_internal:rule.bzl",
    "android_binary_internal_macro",
    "sanitize_attrs",
)
load(":common.bzl", "common")
load(":migration_tag_DONOTUSE.bzl", "add_migration_tag")
load(":proguard.bzl", "proguard")

# A list of Providers that rule android_binary can provide (but not required).
_PROVIDERS = [
    AndroidFeatureFlagSet,
    AndroidIdeInfo,
    AndroidIdlInfo,
    AndroidInstrumentationInfo,
    AndroidPreDexJarInfo,
    DataBindingV2Info,
    JavaInfo,
    OutputGroupInfo,
    ProguardMappingInfo,
]

_ATTRS = _attrs.add(
    _attrs.replace(
        _BASE_ATTRS,
        # Do not apply aspects on the deps attribute of the top-level android_binary rule.
        # They are already applied to the android_binary_internal rule.
        deps = attr.label_list(),
    ),
    dict(
        application_resources = attr.label(
            allow_rules = ["android_binary_internal"],
            mandatory = True,
            providers = [ApkInfo],
        ),
        # This is for only generating proguard outputs when proguard_specs is not empty or of type select.
        _generate_proguard_outputs = attr.bool(),
    ),
)

def _symlink(ctx, files, output, target_file):
    ctx.actions.symlink(
        output = output,
        target_file = target_file,
        progress_message = "Symlinking %s" % output.short_path,
    )
    files.append(output)
    return files

def _symlink_outputs(
        ctx,
        target,
        has_proguard_specs,
        generate_proguard_outputs,
        proguard_generate_mapping):
    files = []

    _symlink(
        ctx,
        files,
        output = ctx.outputs.deploy_jar,
        target_file = target[ApkInfo].deploy_jar,
    )
    _symlink(
        ctx,
        files,
        output = ctx.outputs.unsigned_apk,
        target_file = target[ApkInfo].unsigned_apk,
    )
    _symlink(
        ctx,
        files,
        output = ctx.outputs.signed_apk,
        target_file = target[ApkInfo].signed_apk,
    )

    if has_proguard_specs:
        _symlink(
            ctx,
            files,
            output = ctx.outputs.proguard_jar,
            target_file = target[AndroidOptimizationInfo].optimized_jar,
        )
        _symlink(
            ctx,
            files,
            output = ctx.outputs.proguard_config,
            target_file = target[AndroidOptimizationInfo].config,
        )
        _symlink(
            ctx,
            files,
            output = ctx.actions.declare_file(ctx.label.name + "_proguard.seeds"),
            target_file = target[AndroidOptimizationInfo].seeds,
        )
        _symlink(
            ctx,
            files,
            output = ctx.actions.declare_file(ctx.label.name + "_proguard.usage"),
            target_file = target[AndroidOptimizationInfo].usage,
        )

        if proguard_generate_mapping:
            _symlink(
                ctx,
                files,
                output = ctx.outputs.proguard_map,
                target_file = target[AndroidDexInfo].final_proguard_output_map,
            )
    elif generate_proguard_outputs:
        proguard.create_empty_proguard_output(
            ctx,
            ctx.outputs.proguard_jar,
            ctx.outputs.proguard_config,
            getattr(ctx.outputs, "proguard_map", None),
        )
    else:
        # This happens when proguard_specs is empty or the rule is using R8 for optimization.
        return files

    # TODO(zhaoqxu): Consider removing these symlinks and passing the files directly to the underlying
    # android_binary_internal rule.
    if target[AndroidOptimizationInfo].optimized_resource_apk:
        _symlink(
            ctx,
            files,
            output = ctx.actions.declare_file(ctx.label.name + "_optimized.ap_"),
            target_file = target[AndroidOptimizationInfo].optimized_resource_apk,
        )

    if target[AndroidOptimizationInfo].shrunk_resource_apk:
        _symlink(
            ctx,
            files,
            output = ctx.actions.declare_file(ctx.label.name + "_shrunk.ap_"),
            target_file = target[AndroidOptimizationInfo].shrunk_resource_apk,
        )

    if target[AndroidOptimizationInfo].resource_shrinker_log:
        _symlink(
            ctx,
            files,
            output = ctx.actions.declare_file(ctx.label.name + "_files/resource_shrinker.log"),
            target_file = target[AndroidOptimizationInfo].resource_shrinker_log,
        )

    if target[AndroidOptimizationInfo].resource_optimization_config:
        _symlink(
            ctx,
            files,
            output = ctx.actions.declare_file(ctx.label.name + "_files/resource_optimization.cfg"),
            target_file = target[AndroidOptimizationInfo].resource_optimization_config,
        )

    if target[AndroidOptimizationInfo].resource_path_shortening_map:
        _symlink(
            ctx,
            files,
            output = ctx.actions.declare_file(ctx.label.name + "_resource_paths.map"),
            target_file = target[AndroidOptimizationInfo].resource_path_shortening_map,
        )

    return files

def _impl(ctx):
    target = ctx.attr.application_resources

    files = depset(
        _symlink_outputs(
            ctx,
            target,
            bool(ctx.attr.proguard_specs),
            ctx.attr._generate_proguard_outputs,
            ctx.attr.proguard_generate_mapping,
        ),
        transitive = [target[DefaultInfo].files],
    )

    providers = [
        DefaultInfo(
            files = files,
            runfiles = ctx.runfiles(transitive_files = files),
        ),
        # Reconstructing ApkInfo to use the "right" symlinked outputs. This is necessary because
        # android_instrumentation_test rule gets the signed apk from ApkInfo and put it in in the
        # runfiles, which can then be accessed by other tests or rules.
        ApkInfo(
            signed_apk = ctx.outputs.signed_apk,
            unsigned_apk = ctx.outputs.unsigned_apk,
            deploy_jar = ctx.outputs.deploy_jar,
            coverage_metadata = target[ApkInfo].coverage_metadata,
            # merged_manifest getter is not exposed in ApkInfo, so we have to get it from AndroidIdeInfo.
            merged_manifest = target[AndroidIdeInfo].generated_manifest,
            signing_keys = target[ApkInfo].signing_keys,
            signing_lineage = target[ApkInfo].signing_lineage,
            signing_min_v3_rotation_api_version = target[ApkInfo].signing_min_v3_rotation_api_version,
        ),
    ] + [target[p] for p in _PROVIDERS if p in target]

    return providers

def _outputs(name, proguard_generate_mapping, _generate_proguard_outputs):
    outputs = dict(
        deploy_jar = "%{name}_deploy.jar",
        unsigned_apk = "%{name}_unsigned.apk",
        signed_apk = "%{name}.apk",
    )

    # proguard_specs is too valuable an attribute to make it nonconfigurable, so if its value is
    # configurable (i.e. of type 'select'), _generate_proguard_outputs will be set to True and the
    # predeclared proguard outputs will be generated. If the proguard_specs attribute resolves to an
    # empty list eventually, we do not use it in the dexing. If user explicitly tries to request it,
    # it will fail.
    if _generate_proguard_outputs:
        outputs["proguard_jar"] = "%{name}_proguard.jar"
        outputs["proguard_config"] = "%{name}_proguard.config"
        if proguard_generate_mapping:
            outputs["proguard_map"] = "%{name}_proguard.map"
    return outputs

def make_rule(attrs = _ATTRS):
    return rule(
        attrs = attrs,
        implementation = _impl,
        provides = [ApkInfo],
        cfg = android_platforms_transition,
        outputs = _outputs,
    )

# TODO(b/329267394): Merge this rule with android_binary_internal once b/319665411 is fixed.
android_binary = make_rule()

def android_binary_macro(**attrs):
    """Bazel android_binary rule.

    https://docs.bazel.build/versions/master/be/android.html#android_binary

    Args:
      **attrs: Rule attributes
    """
    android_binary_internal_name = ":" + attrs["name"] + common.PACKAGED_RESOURCES_SUFFIX
    android_binary_internal_macro(
        **dict(
            attrs,
            name = android_binary_internal_name[1:],
            visibility = ["//visibility:private"],
        )
    )

    attrs.pop("$enable_manifest_merging", None)

    # dex_shards is deprecated and unused. This only existed for mobile-install classic which has
    # been replaced by mobile-install v2
    attrs.pop("dex_shards", None)

    # resource_apks is not used by the native android_binary
    attrs.pop("resource_apks", None)

    fqn = "//%s:%s" % (native.package_name(), attrs["name"])
    if acls.use_r8(fqn):
        # Do not pass proguard specs to the native android_binary so that it does
        # not try to use proguard and instead uses the dex files from the
        # AndroidDexInfo provider from android_binary_internal.
        # This also disables resource shrinking from native android_binary (reguardless of the
        # shrink_resources attr).
        attrs["proguard_specs"] = []

    if acls.in_android_binary_starlark_rollout(fqn):
        if type(attrs.get("proguard_specs", None)) == "select" or attrs.get("proguard_specs", None):
            attrs["$generate_proguard_outputs"] = True

        android_binary(
            application_resources = android_binary_internal_name,
            **add_migration_tag(sanitize_attrs(
                attrs,
                allowed_attrs = _ATTRS.keys() + ["$generate_proguard_outputs"],
            ))
        )
    else:
        native.android_binary(
            application_resources = android_binary_internal_name,
            **add_migration_tag(attrs)
        )
