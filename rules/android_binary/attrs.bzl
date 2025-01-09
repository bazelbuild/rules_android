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
"""Attributes."""

load("//providers:providers.bzl", "StarlarkApkInfo")
load("//rules:android_neverlink_aspect.bzl", "android_neverlink_aspect")
load("//rules:android_platforms_transition.bzl", "android_platforms_transition")
load("//rules:android_split_transition.bzl", "android_split_transition", "android_transition")
load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
load("//rules:dex_desugar_aspect.bzl", "dex_desugar_aspect")
load(
    "//rules:native_deps.bzl",
    "split_config_aspect",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

visibility(PROJECT_VISIBILITY)

def make_deps(allow_rules, providers, aspects):
    return attr.label_list(
        allow_files = True,
        allow_rules = allow_rules,
        providers = providers,
        aspects = aspects,
        cfg = android_split_transition,
    )

DEPS_ALLOW_RULES = [
    "aar_import",
    "android_library",
    "cc_library",
    "java_import",
    "java_library",
    "java_lite_proto_library",
]

DEPS_PROVIDERS = [
    [CcInfo],
    [JavaInfo],
]

DEPS_ASPECTS = [
    dex_desugar_aspect,
    android_neverlink_aspect,
]

ATTRS = _attrs.replace(
    _attrs.add(
        dict(
            srcs = attr.label_list(
                # TODO(timpeut): Set PropertyFlag direct_compile_time_input
                allow_files = [".java", ".srcjar"],
            ),
            deps = make_deps(DEPS_ALLOW_RULES, DEPS_PROVIDERS, DEPS_ASPECTS),
            enable_data_binding = attr.bool(),
            instruments = attr.label(),
            manifest_values = attr.string_dict(),
            manifest_merger = attr.string(
                default = "android",
                values = ["auto", "legacy", "android", "force_android"],
            ),
            native_target = attr.label(
                allow_files = False,
                allow_rules = ["android_binary", "android_test"],
                cfg = android_platforms_transition,
            ),
            generate_art_profile = attr.bool(
                default = True,
                doc = """
                Whether to generate ART profile. If true, the ART profile will be generated
                and bundled into your APK’s asset directory. During APK installation, Android
                Runtime(ART) will perform Ahead-of-time (AOT) compilation of methods in the
                profile, speeding up app startup time or reducing jank in some circumstances.
                """,
            ),
            startup_profiles = attr.label_list(
                allow_empty = True,
                allow_files = [".txt"],
                doc = """
                List of baseline profiles that were collected at runtime (often from start-up) for
                this binary. When this is specified, all baseline profiles (including these) are
                used to inform code optimizations in the build toolchain. This may improve runtime
                performance at the cost of dex size. If the dex size cost is too large and the
                performance wins too small, the same profiles can be provided as a dep from an
                android_library with `baseline_profiles` to avoid the runtime-focused code
                optimizations that are enabled by `startup_profiles`.
                """,
                cfg = android_platforms_transition,
            ),
            proguard_specs = attr.label_list(allow_empty = True, allow_files = True, cfg = android_platforms_transition),
            resource_apks = attr.label_list(
                allow_rules = ["apk_import"],
                providers = [
                    [StarlarkApkInfo],
                ],
                doc = (
                    "List of resource only apks to link against."
                ),
                cfg = android_platforms_transition,
            ),
            resource_configuration_filters = attr.string_list(),
            densities = attr.string_list(),
            nocompress_extensions = attr.string_list(),
            shrink_resources = _attrs.tristate.create(
                default = _attrs.tristate.auto,
            ),
            dexopts = attr.string_list(),
            main_dex_list = attr.label(allow_single_file = True, cfg = android_platforms_transition),
            main_dex_list_opts = attr.string_list(),
            main_dex_proguard_specs = attr.label_list(allow_empty = True, allow_files = True, cfg = android_transition),
            min_sdk_version = attr.int(),
            incremental_dexing = _attrs.tristate.create(
                default = _attrs.tristate.auto,
            ),
            proguard_generate_mapping = attr.bool(default = False),
            proguard_optimization_passes = attr.int(),
            proguard_apply_mapping = attr.label(allow_single_file = True, cfg = android_platforms_transition),
            feature_flags = attr.label_keyed_string_dict(
                allow_rules = ["config_feature_flag"],
                providers = [config_common.FeatureFlagInfo],
            ),
            multidex = attr.string(
                default = "native",
                values = ["native", "legacy", "manual_main_dex"],
            ),
            debug_key = attr.label(
                cfg = "exec",
                default = "//tools/android:debug_keystore",
                allow_single_file = True,
                doc = """
                      File containing the debug keystore to be used to sign the debug apk. Usually
                      you do not want to use a key other than the default key, so this attribute
                      should be omitted.

                      WARNING: Do not use your production keys, they should be strictly safeguarded
                      and not kept in your source tree.
                      """,
            ),
            debug_signing_keys = attr.label_list(
                allow_files = True,
                doc = """
                      List of files, debug keystores to be used to sign the debug apk. Usually you
                      do not want to use keys other than the default key, so this attribute should
                      be omitted.

                      WARNING: Do not use your production keys, they should be strictly safeguarded
                      and not kept in your source tree.
                      """,
                cfg = android_platforms_transition,
            ),
            debug_signing_lineage_file = attr.label(
                allow_single_file = True,
                doc = """
                      File containing the signing lineage for the debug_signing_keys. Usually you
                      do not want to use keys other than the default key, so this attribute should
                      be omitted.

                      WARNING: Do not use your production keys, they should be strictly safeguarded
                      and not kept in your source tree.
                      """,
                cfg = android_platforms_transition,
            ),
            key_rotation_min_sdk = attr.string(
                doc = """
                      Sets the minimum Android platform version (API Level) for which an APK's
                      rotated signing key should be used to produce the APK's signature. The
                      original signing key for the APK will be used for all previous platform
                      versions.
                      """,
            ),
            use_r_package = attr.bool(
                default = False,
                doc = """
                      Whether resource fields should be generated with an RPackage class.
                      Used ONLY for privacy sandbox.

                      WARNING: Do not use outside of privacy sandbox build rules.
                      """,
            ),
            _java_toolchain = attr.label(
                default = Label("//tools/jdk:toolchain_android_only"),
            ),
            _defined_resource_files = attr.bool(default = False),
            _package_name = attr.string(),  # for sending the package name to the outputs callback
            # This is for only generating proguard outputs when proguard_specs is not empty or of type select.
            _generate_proguard_outputs = attr.bool(),
            _enable_manifest_merging = attr.bool(default = True),
            _cc_toolchain_split = attr.label(
                cfg = android_split_transition,
                default = "@bazel_tools//tools/cpp:current_cc_toolchain",
                aspects = [split_config_aspect],
            ),
            _optimizing_dexer = attr.label(
                cfg = "exec",
                allow_single_file = True,
                default = configuration_field(
                    fragment = "android",
                    name = "optimizing_dexer",
                ),
            ),
            _desugared_java8_legacy_apis = attr.label(
                default = Label("//tools/android:desugared_java8_legacy_apis"),
                allow_single_file = True,
                cfg = android_platforms_transition,
            ),
            _bytecode_optimizer = attr.label(
                default = configuration_field(
                    fragment = "java",
                    name = "bytecode_optimizer",
                ),
                cfg = "exec",
                executable = True,
            ),
            _legacy_main_dex_list_generator = attr.label(
                default = configuration_field(
                    fragment = "android",
                    name = "legacy_main_dex_list_generator",
                ),
                cfg = "exec",
                executable = True,
            ),
            _manifest_merge_order = attr.label(
                default = "//rules/flags:manifest_merge_order",
            ),
            _rewrite_resources_through_optimizer = attr.bool(
                default = False,
                doc = """
                Allow for the optimizer to process resources. This is not supported in proguard.
                """,
            ),
        ),
        _attrs.compilation_attributes(apply_android_transition = True),
        _attrs.DATA_CONTEXT,
        _attrs.ANDROID_TOOLCHAIN_ATTRS,
        _attrs.AUTOMATIC_EXEC_GROUPS_ENABLED,
    ),
    # TODO(b/167599192): don't override manifest attr to remove .xml file restriction.
    manifest = attr.label(
        allow_single_file = True,
        # TODO(b/328051443): Apply the android_transition
        cfg = android_platforms_transition,
    ),
)
