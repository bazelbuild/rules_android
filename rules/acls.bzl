# Copyright 2020 The Bazel Authors. All rights reserved.
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
"""Access Control Lists.

To create a new list:
  1. Create new .bzl file in the acls directory with a list of targets.
  2. Create matching method in this file.
  3. Add matching method to struct.

To check an ACL:
  1. Import the `acls` struct.
  2. Check `acls.list_name(fqn)` using the //fully/qualified:target

To update a list:
  1. Directly add/remove/edit targets in the appropriate .bzl file
"""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//rules/acls:aar_import_deps_checker.bzl", "AAR_IMPORT_DEPS_CHECKER_FALLBACK", "AAR_IMPORT_DEPS_CHECKER_ROLLOUT")
load("//rules/acls:aar_import_explicit_exports_manifest.bzl", "AAR_IMPORT_EXPLICIT_EXPORTS_MANIFEST")
load("//rules/acls:aar_import_exports_r_java.bzl", "AAR_IMPORT_EXPORTS_R_JAVA")
load("//rules/acls:allow_resource_conflicts.bzl", "ALLOW_RESOURCE_CONFLICTS")
load("//rules/acls:android_apk_to_bundle_features_lockdown.bzl", "ANDROID_APK_TO_BUNDLE_FEATURES")
load("//rules/acls:android_application_with_sandboxed_sdks_allowlist.bzl", "ANDROID_APPLICATION_WITH_SANDBOXED_SDKS_ALLOWLIST")
load("//rules/acls:android_archive_dogfood.bzl", "ANDROID_ARCHIVE_DOGFOOD")
load("//rules/acls:android_archive_duplicate_class_allowlist.bzl", "ANDROID_ARCHIVE_DUPLICATE_CLASS_ALLOWLIST")
load("//rules/acls:android_archive_excluded_deps_denylist.bzl", "ANDROID_ARCHIVE_EXCLUDED_DEPS_DENYLIST")
load("//rules/acls:android_archive_exposed_package_allowlist.bzl", "ANDROID_ARCHIVE_EXPOSED_PACKAGE_ALLOWLIST")
load("//rules/acls:android_binary_min_sdk_version_attribute.bzl", "ANDROID_BINARY_MIN_SDK_VERSION_ATTRIBUTE_ALLOWLIST")
load("//rules/acls:android_binary_raw_access_to_resource_paths_allowlist.bzl", "ANDROID_BINARY_RAW_ACCESS_TO_RESOURCE_PATHS_ALLOWLIST")
load("//rules/acls:android_binary_resource_name_obfuscation_opt_out_allowlist.bzl", "ANDROID_BINARY_RESOURCE_NAME_OBFUSCATION_OPT_OUT_ALLOWLIST")
load("//rules/acls:android_binary_resource_shrinking_in_optimizer_rollout.bzl", "RESOURCE_SHRINKING_IN_OPTIMIZER_FALLBACK", "RESOURCE_SHRINKING_IN_OPTIMIZER_ROLLOUT")
load("//rules/acls:android_binary_with_sandboxed_sdks_allowlist.bzl", "ANDROID_BINARY_WITH_SANDBOXED_SDKS_ALLOWLIST")
load("//rules/acls:android_build_stamping_rollout.bzl", "ANDROID_BUILD_STAMPING_FALLBACK", "ANDROID_BUILD_STAMPING_ROLLOUT")
load("//rules/acls:android_feature_splits_dogfood.bzl", "ANDROID_FEATURE_SPLITS_DOGFOOD")
load("//rules/acls:android_instrumentation_test_manifest_check_rollout.bzl", "ANDROID_INSTRUMENTATION_TEST_MANIFEST_CHECK_FALLBACK", "ANDROID_INSTRUMENTATION_TEST_MANIFEST_CHECK_ROLLOUT")
load("//rules/acls:android_instrumentation_test_prebuilt_test_apk.bzl", "ANDROID_INSTRUMENTATION_TEST_PREBUILT_TEST_APK_FALLBACK", "ANDROID_INSTRUMENTATION_TEST_PREBUILT_TEST_APK_ROLLOUT")
load("//rules/acls:android_library_resources_without_srcs.bzl", "ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS", "ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS_GENERATOR_FUNCTIONS")
load("//rules/acls:android_library_starlark_resource_outputs.bzl", "ANDROID_LIBRARY_STARLARK_RESOURCE_OUTPUTS_FALLBACK", "ANDROID_LIBRARY_STARLARK_RESOURCE_OUTPUTS_ROLLOUT")
load("//rules/acls:android_library_use_aosp_aidl_compiler.bzl", "ANDROID_LIBRARY_USE_AOSP_AIDL_COMPILER_ALLOWLIST")
load("//rules/acls:android_lint_checks_rollout.bzl", "ANDROID_LINT_CHECKS_FALLBACK", "ANDROID_LINT_CHECKS_ROLLOUT")
load("//rules/acls:android_lint_rollout.bzl", "ANDROID_LINT_FALLBACK", "ANDROID_LINT_ROLLOUT")
load("//rules/acls:android_test_lockdown.bzl", "ANDROID_TEST_LOCKDOWN_GENERATOR_FUNCTIONS", "ANDROID_TEST_LOCKDOWN_TARGETS")
load("//rules/acls:b122039567.bzl", "B122039567")
load("//rules/acls:baseline_profiles_optimizer_integration.bzl", "BASELINE_PROFILES_OPTIMIZER_INTEGRATION", "BASELINE_PROFILES_OPTIMIZER_INTEGRATION_FALLBACK")
load("//rules/acls:baseline_profiles_rollout.bzl", "BASELINE_PROFILES_ROLLOUT")
load("//rules/acls:databinding.bzl", "DATABINDING_ALLOWED", "DATABINDING_DISALLOWED")
load("//rules/acls:dex2oat_opts.bzl", "CAN_USE_DEX2OAT_OPTIONS")
load("//rules/acls:disable_optimizing_dexer.bzl", "DISABLE_OPTIMIZING_DEXER")
load("//rules/acls:force_final_resources.bzl", "FORCE_FINAL_ANDROID_BINARY_RESOURCES")
load("//rules/acls:install_apps_in_data.bzl", "INSTALL_APPS_IN_DATA")
load("//rules/acls:lint_registry_rollout.bzl", "LINT_REGISTRY_FALLBACK", "LINT_REGISTRY_ROLLOUT")
load("//rules/acls:local_test_multi_proto.bzl", "LOCAL_TEST_MULTI_PROTO_PKG")
load("//rules/acls:optimizer_execution_requirements.bzl", "OPTIMIZER_EXECUTION_REQUIREMENTS")
load(
    "//rules/acls:partial_jetification_targets.bzl",
    "PARTIAL_JETIFICATION_TARGETS_FALLBACK",
    "PARTIAL_JETIFICATION_TARGETS_ROLLOUT",
)
load("//rules/acls:proguard_apply_mapping.bzl", "ALLOW_PROGUARD_APPLY_MAPPING")
load("//rules/acls:r8.bzl", "USE_R8")
load("//rules/acls:record_desugaring.bzl", "RECORD_DESUGARING_FALLBACK", "RECORD_DESUGARING_ROLLOUT")
load("//rules/acls:shared_library_resource_linking.bzl", "SHARED_LIBRARY_RESOURCE_LINKING_ALLOWLIST")
load("//rules/acls:stamp_signing.bzl", "STAMP_SIGNING_FALLBACK", "STAMP_SIGNING_ROLLOUT")
load("//rules/acls:test_to_instrument_test_rollout.bzl", "TEST_TO_INSTRUMENT_TEST_FALLBACK", "TEST_TO_INSTRUMENT_TEST_ROLLOUT")

visibility(PROJECT_VISIBILITY)

def _in_aar_import_deps_checker(fqn):
    return not matches(fqn, AAR_IMPORT_DEPS_CHECKER_FALLBACK_DICT) and matches(fqn, AAR_IMPORT_DEPS_CHECKER_ROLLOUT_DICT)

def _in_aar_import_explicit_exports_manifest(fqn):
    return matches(fqn, AAR_IMPORT_EXPLICIT_EXPORTS_MANIFEST_DICT)

def _in_aar_import_exports_r_java(fqn):
    return matches(fqn, AAR_IMPORT_EXPORTS_R_JAVA_DICT)

def _in_android_application_with_sandboxed_sdks_allowlist_dict(fqn):
    return matches(fqn, ANDROID_APPLICATION_WITH_SANDBOXED_SDKS_ALLOWLIST_DICT)

def _in_android_archive_dogfood(fqn):
    return matches(fqn, ANDROID_ARCHIVE_DOGFOOD_DICT)

def _in_android_archive_excluded_deps_denylist(fqn):
    return matches(fqn, ANDROID_ARCHIVE_EXCLUDED_DEPS_DENYLIST_DICT)

def _in_android_binary_with_sandboxed_sdks_allowlist(fqn):
    return matches(fqn, ANDROID_BINARY_WITH_SANDBOXED_SDKS_ALLOWLIST_DICT)

def _in_android_feature_splits_dogfood(fqn):
    return matches(fqn, ANDROID_FEATURE_SPLITS_DOGFOOD_DICT)

def _in_android_lint_checks_rollout(fqn):
    return not matches(fqn, ANDROID_LINT_CHECKS_FALLBACK_DICT) and matches(fqn, ANDROID_LINT_CHECKS_ROLLOUT_DICT)

def _in_android_lint_rollout(fqn):
    return not matches(fqn, ANDROID_LINT_FALLBACK_DICT) and matches(fqn, ANDROID_LINT_ROLLOUT_DICT)

def _in_lint_registry_rollout(fqn):
    return not matches(fqn, LINT_REGISTRY_FALLBACK_DICT) and matches(fqn, LINT_REGISTRY_ROLLOUT_DICT)

def _in_android_build_stamping_rollout(fqn):
    return not matches(fqn, ANDROID_BUILD_STAMPING_FALLBACK_DICT) and matches(fqn, ANDROID_BUILD_STAMPING_ROLLOUT_DICT)

def _in_android_test_lockdown_allowlist(fqn, generator):
    if generator == "android_test":
        return matches(fqn, ANDROID_TEST_LOCKDOWN_TARGETS)
    return generator in ANDROID_TEST_LOCKDOWN_GENERATOR_FUNCTIONS_DICT

def _in_b122039567(fqn):
    return matches(fqn, B122039567_DICT)

def _in_android_library_resources_without_srcs(fqn):
    return matches(fqn, ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS_DICT)

def _in_android_library_resources_without_srcs_generator_functions(gfn):
    return gfn in ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS_GENERATOR_FUNCTIONS_DICT

def _in_android_library_starlark_resource_outputs_rollout(fqn):
    return not matches(fqn, ANDROID_LIBRARY_STARLARK_RESOURCE_OUTPUTS_FALLBACK_DICT) and matches(fqn, ANDROID_LIBRARY_STARLARK_RESOURCE_OUTPUTS_ROLLOUT_DICT)

def _in_android_library_use_aosp_aidl_compiler_allowlist(fqn):
    return matches(fqn, ANDROID_LIBRARY_USE_AOSP_AIDL_COMPILER_ALLOWLIST_DICT)

def _in_databinding_allowed(fqn):
    return not matches(fqn, DATABINDING_DISALLOWED_DICT) and matches(fqn, DATABINDING_ALLOWED_DICT)

def _in_dex2oat_opts(fqn):
    return matches(fqn, CAN_USE_DEX2OAT_OPTIONS_DICT)

def _in_install_apps_in_data(fqn):
    return matches(fqn, AIT_INSTALL_APPS_IN_DATA_DICT)

def _in_local_test_multi_proto(fqn):
    return matches(fqn, LOCAL_TEST_MULTI_PROTO_PKG_DICT)

def _in_test_to_instrument_test_rollout(fqn):
    return not matches(fqn, TEST_TO_INSTRUMENT_TEST_FALLBACK_DICT) and matches(fqn, TEST_TO_INSTRUMENT_TEST_ROLLOUT_DICT)

def _in_allow_resource_conflicts(fqn):
    return matches(fqn, ALLOW_RESOURCE_CONFLICTS_DICT)

def _in_partial_jetification_targets(fqn):
    return not matches(fqn, PARTIAL_JETIFICATION_TARGETS_FALLBACK_DICT) and matches(fqn, PARTIAL_JETIFICATION_TARGETS_ROLLOUT_DICT)

def _in_android_instrumentation_test_manifest_check_rollout(fqn):
    return not matches(fqn, ANDROID_INSTRUMENTATION_TEST_MANIFEST_CHECK_FALLBACK_DICT) and matches(fqn, ANDROID_INSTRUMENTATION_TEST_MANIFEST_CHECK_ROLLOUT_DICT)

def _in_android_instrumentation_test_prebuilt_test_apk(fqn):
    return matches(fqn, ANDROID_INSTRUMENTATION_TEST_PREBUILT_TEST_APK_ROLLOUT_DICT) and not matches(fqn, ANDROID_INSTRUMENTATION_TEST_PREBUILT_TEST_APK_FALLBACK_DICT)

def _get_android_archive_exposed_package_allowlist(fqn):
    return ANDROID_ARCHIVE_EXPOSED_PACKAGE_ALLOWLIST.get(fqn, [])

def _in_baseline_profiles_rollout(fqn):
    return matches(fqn, BASELINE_PROFILES_ROLLOUT)

def _in_baseline_profiles_optimizer_integration(fqn):
    return matches(fqn, BASELINE_PROFILES_OPTIMIZER_INTEGRATION_DICT) and not matches(fqn, BASELINE_PROFILES_OPTIMIZER_INTEGRATION_FALLBACK_DICT)

def _in_android_apk_to_bundle_features(fqn):
    return matches(fqn, ANDROID_APK_TO_BUNDLE_FEATURES_DICT)

def _get_android_archive_duplicate_class_allowlist(fqn):
    return ANDROID_ARCHIVE_DUPLICATE_CLASS_ALLOWLIST.get(fqn, [])

def _in_shared_library_resource_linking_allowlist(fqn):
    return matches(fqn, SHARED_LIBRARY_RESOURCE_LINKING_DICT)

def _in_android_binary_min_sdk_version_attribute_allowlist(fqn):
    return matches(fqn, ANDROID_BINARY_MIN_SDK_VERSION_ATTRIBUTE_DICT)

def _in_android_binary_raw_access_to_resource_paths_allowlist(fqn):
    return matches(fqn, ANDROID_BINARY_RAW_ACCESS_TO_RESOURCE_PATHS_ALLOWLIST_DICT)

def _in_android_binary_resource_name_obfuscation_opt_out_allowlist(fqn):
    return matches(fqn, ANDROID_BINARY_RESOURCE_NAME_OBFUSCATION_OPT_OUT_ALLOWLIST_DICT)

def _in_allow_proguard_apply_mapping(fqn):
    return matches(fqn, ALLOW_PROGUARD_APPLY_MAPPING_DICT)

def _use_r8(fqn):
    return matches(fqn, USE_R8_DICT)

def _in_disable_optimizing_dexer(fqn):
    return matches(fqn, DISABLE_OPTIMIZING_DEXER_DICT)

def _in_force_final_android_binary_resources(fqn):
    return matches(fqn, FORCE_FINAL_ANDROID_BINARY_RESOURCES_DICT)

def _in_resource_shrinking_in_optimizer(fqn):
    return matches(fqn, RESOURCE_SHRINKING_IN_OPTIMIZER_ROLLOUT_DICT) and not matches(fqn, RESOURCE_SHRINKING_IN_OPTIMIZER_FALLBACK_DICT)

def _in_record_desugaring_rollout(fqn):
    return matches(fqn, RECORD_DESUGARING_ROLLOUT_DICT) and not matches(fqn, RECORD_DESUGARING_FALLBACK_DICT)

def _get_optimizer_execution_requirements(target_package):
    return OPTIMIZER_EXECUTION_REQUIREMENTS.get(target_package, None)

def _in_stamp_signing_rollout(fqn):
    return matches(fqn, STAMP_SIGNING_ROLLOUT_DICT) and not matches(fqn, STAMP_SIGNING_FALLBACK_DICT)

def make_dict(lst):
    """Do not use this method outside of acls directory."""
    return {t: True for t in lst}

def make_min_sdk_dict(dict_of_lists):
    res = {}
    for k in dict_of_lists.keys():
        res[k] = make_dict(dict_of_lists[k])
    return res

AAR_IMPORT_DEPS_CHECKER_FALLBACK_DICT = make_dict(AAR_IMPORT_DEPS_CHECKER_FALLBACK)
AAR_IMPORT_DEPS_CHECKER_ROLLOUT_DICT = make_dict(AAR_IMPORT_DEPS_CHECKER_ROLLOUT)
AAR_IMPORT_EXPLICIT_EXPORTS_MANIFEST_DICT = make_dict(AAR_IMPORT_EXPLICIT_EXPORTS_MANIFEST)
AAR_IMPORT_EXPORTS_R_JAVA_DICT = make_dict(AAR_IMPORT_EXPORTS_R_JAVA)
ANDROID_APPLICATION_WITH_SANDBOXED_SDKS_ALLOWLIST_DICT = make_dict(ANDROID_APPLICATION_WITH_SANDBOXED_SDKS_ALLOWLIST)
ANDROID_ARCHIVE_DOGFOOD_DICT = make_dict(ANDROID_ARCHIVE_DOGFOOD)
ANDROID_ARCHIVE_EXCLUDED_DEPS_DENYLIST_DICT = make_dict(ANDROID_ARCHIVE_EXCLUDED_DEPS_DENYLIST)
ANDROID_BINARY_WITH_SANDBOXED_SDKS_ALLOWLIST_DICT = make_dict(ANDROID_BINARY_WITH_SANDBOXED_SDKS_ALLOWLIST)
ANDROID_FEATURE_SPLITS_DOGFOOD_DICT = make_dict(ANDROID_FEATURE_SPLITS_DOGFOOD)
ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS_DICT = make_dict(ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS)
ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS_GENERATOR_FUNCTIONS_DICT = make_dict(ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS_GENERATOR_FUNCTIONS)
ANDROID_LIBRARY_STARLARK_RESOURCE_OUTPUTS_FALLBACK_DICT = make_dict(ANDROID_LIBRARY_STARLARK_RESOURCE_OUTPUTS_FALLBACK)
ANDROID_LIBRARY_STARLARK_RESOURCE_OUTPUTS_ROLLOUT_DICT = make_dict(ANDROID_LIBRARY_STARLARK_RESOURCE_OUTPUTS_ROLLOUT)
ANDROID_LINT_CHECKS_FALLBACK_DICT = make_dict(ANDROID_LINT_CHECKS_FALLBACK)
ANDROID_LINT_CHECKS_ROLLOUT_DICT = make_dict(ANDROID_LINT_CHECKS_ROLLOUT)
ANDROID_LINT_FALLBACK_DICT = make_dict(ANDROID_LINT_FALLBACK)
ANDROID_LINT_ROLLOUT_DICT = make_dict(ANDROID_LINT_ROLLOUT)

LINT_REGISTRY_FALLBACK_DICT = make_dict(LINT_REGISTRY_FALLBACK)
LINT_REGISTRY_ROLLOUT_DICT = make_dict(LINT_REGISTRY_ROLLOUT)
ANDROID_BUILD_STAMPING_ROLLOUT_DICT = make_dict(ANDROID_BUILD_STAMPING_ROLLOUT)
ANDROID_BUILD_STAMPING_FALLBACK_DICT = make_dict(ANDROID_BUILD_STAMPING_FALLBACK)
ANDROID_TEST_LOCKDOWN_GENERATOR_FUNCTIONS_DICT = make_dict(ANDROID_TEST_LOCKDOWN_GENERATOR_FUNCTIONS)
ANDROID_TEST_LOCKDOWN_TARGETS_DICT = make_dict(ANDROID_TEST_LOCKDOWN_TARGETS)
B122039567_DICT = make_dict(B122039567)
CAN_USE_DEX2OAT_OPTIONS_DICT = make_dict(CAN_USE_DEX2OAT_OPTIONS)
AIT_INSTALL_APPS_IN_DATA_DICT = make_dict(INSTALL_APPS_IN_DATA)
LOCAL_TEST_MULTI_PROTO_PKG_DICT = make_dict(LOCAL_TEST_MULTI_PROTO_PKG)
TEST_TO_INSTRUMENT_TEST_FALLBACK_DICT = make_dict(TEST_TO_INSTRUMENT_TEST_FALLBACK)
TEST_TO_INSTRUMENT_TEST_ROLLOUT_DICT = make_dict(TEST_TO_INSTRUMENT_TEST_ROLLOUT)
ALLOW_RESOURCE_CONFLICTS_DICT = make_dict(ALLOW_RESOURCE_CONFLICTS)
PARTIAL_JETIFICATION_TARGETS_ROLLOUT_DICT = make_dict(PARTIAL_JETIFICATION_TARGETS_ROLLOUT)
PARTIAL_JETIFICATION_TARGETS_FALLBACK_DICT = make_dict(PARTIAL_JETIFICATION_TARGETS_FALLBACK)
ANDROID_INSTRUMENTATION_TEST_MANIFEST_CHECK_ROLLOUT_DICT = make_dict(ANDROID_INSTRUMENTATION_TEST_MANIFEST_CHECK_ROLLOUT)
ANDROID_INSTRUMENTATION_TEST_MANIFEST_CHECK_FALLBACK_DICT = make_dict(ANDROID_INSTRUMENTATION_TEST_MANIFEST_CHECK_FALLBACK)
ANDROID_INSTRUMENTATION_TEST_PREBUILT_TEST_APK_ROLLOUT_DICT = make_dict(ANDROID_INSTRUMENTATION_TEST_PREBUILT_TEST_APK_ROLLOUT)
ANDROID_INSTRUMENTATION_TEST_PREBUILT_TEST_APK_FALLBACK_DICT = make_dict(ANDROID_INSTRUMENTATION_TEST_PREBUILT_TEST_APK_FALLBACK)
BASELINE_PROFILES_ROLLOUT_DICT = make_dict(BASELINE_PROFILES_ROLLOUT)
BASELINE_PROFILES_OPTIMIZER_INTEGRATION_DICT = make_dict(BASELINE_PROFILES_OPTIMIZER_INTEGRATION)
BASELINE_PROFILES_OPTIMIZER_INTEGRATION_FALLBACK_DICT = make_dict(BASELINE_PROFILES_OPTIMIZER_INTEGRATION_FALLBACK)
ANDROID_APK_TO_BUNDLE_FEATURES_DICT = make_dict(ANDROID_APK_TO_BUNDLE_FEATURES)
ANDROID_LIBRARY_USE_AOSP_AIDL_COMPILER_ALLOWLIST_DICT = make_dict(ANDROID_LIBRARY_USE_AOSP_AIDL_COMPILER_ALLOWLIST)
DATABINDING_ALLOWED_DICT = make_dict(DATABINDING_ALLOWED)
DATABINDING_DISALLOWED_DICT = make_dict(DATABINDING_DISALLOWED)
SHARED_LIBRARY_RESOURCE_LINKING_DICT = make_dict(SHARED_LIBRARY_RESOURCE_LINKING_ALLOWLIST)
ANDROID_BINARY_MIN_SDK_VERSION_ATTRIBUTE_DICT = make_dict(ANDROID_BINARY_MIN_SDK_VERSION_ATTRIBUTE_ALLOWLIST)
ANDROID_BINARY_RAW_ACCESS_TO_RESOURCE_PATHS_ALLOWLIST_DICT = make_dict(ANDROID_BINARY_RAW_ACCESS_TO_RESOURCE_PATHS_ALLOWLIST)
ANDROID_BINARY_RESOURCE_NAME_OBFUSCATION_OPT_OUT_ALLOWLIST_DICT = make_dict(ANDROID_BINARY_RESOURCE_NAME_OBFUSCATION_OPT_OUT_ALLOWLIST)
ALLOW_PROGUARD_APPLY_MAPPING_DICT = make_dict(ALLOW_PROGUARD_APPLY_MAPPING)
USE_R8_DICT = make_dict(USE_R8)
RESOURCE_SHRINKING_IN_OPTIMIZER_ROLLOUT_DICT = make_dict(RESOURCE_SHRINKING_IN_OPTIMIZER_ROLLOUT)
RESOURCE_SHRINKING_IN_OPTIMIZER_FALLBACK_DICT = make_dict(RESOURCE_SHRINKING_IN_OPTIMIZER_FALLBACK)
DISABLE_OPTIMIZING_DEXER_DICT = make_dict(DISABLE_OPTIMIZING_DEXER)
FORCE_FINAL_ANDROID_BINARY_RESOURCES_DICT = make_dict(FORCE_FINAL_ANDROID_BINARY_RESOURCES)
RECORD_DESUGARING_FALLBACK_DICT = make_dict(RECORD_DESUGARING_FALLBACK)
RECORD_DESUGARING_ROLLOUT_DICT = make_dict(RECORD_DESUGARING_ROLLOUT)
STAMP_SIGNING_ROLLOUT_DICT = make_dict(STAMP_SIGNING_ROLLOUT)
STAMP_SIGNING_FALLBACK_DICT = make_dict(STAMP_SIGNING_FALLBACK)

def matches(fqn, dct):
    # Labels with workspace names ("@workspace//pkg:target") are not supported.
    # For now, default external dependency ACLs to True to enable rollout features for all
    # external users. See https://github.com/bazelbuild/rules_android/issues/68
    # Note that this only affects Bazel builds with OSS rules_android.
    if fqn.startswith("@") and not fqn.startswith("@//") and not fqn.startswith("@@//"):
        return True

    # "@//" is the same as the main workspace. It's not completely accurate to treat these as
    # absolute labels, because "@//" from within an external repository refers to the main
    # workspace, and "//" from within an external repository refers to labels within that
    # repository, but this should be fine for ACL resolution.
    if fqn.startswith("@//"):
        fqn = fqn[1:]

    # "@@//" refers to the canonical name of the main repository.
    if fqn.startswith("@@//"):
        fqn = fqn[2:]

    if not fqn.startswith("//"):
        fail("Fully qualified target should start with '//', got: " + fqn)

    if fqn in dct:
        return True

    pkg_and_target = fqn.split(":")
    if len(pkg_and_target) != 2:
        fail("Expected fully qualified target, got: " + fqn)
    pkg = pkg_and_target[0]

    if (pkg + ":__pkg__") in dct:
        return True

    pkg = pkg.lstrip("//")
    pkg_parts = pkg.split("/")
    ancestor_pkg = "//"

    if (ancestor_pkg + ":__subpackages__") in dct:
        return True

    for pkg_part in pkg_parts:
        ancestor_pkg = (
            (ancestor_pkg + "/" + pkg_part) if ancestor_pkg != "//" else ("//" + pkg_part)
        )
        if (ancestor_pkg + ":__subpackages__") in dct:
            return True

    return False

acls = struct(
    get_android_archive_duplicate_class_allowlist = _get_android_archive_duplicate_class_allowlist,
    get_android_archive_exposed_package_allowlist = _get_android_archive_exposed_package_allowlist,
    get_optimizer_execution_requirements = _get_optimizer_execution_requirements,
    in_aar_import_deps_checker = _in_aar_import_deps_checker,
    in_aar_import_explicit_exports_manifest = _in_aar_import_explicit_exports_manifest,
    in_aar_import_exports_r_java = _in_aar_import_exports_r_java,
    in_b122039567 = _in_b122039567,
    in_android_application_with_sandboxed_sdks_allowlist_dict = _in_android_application_with_sandboxed_sdks_allowlist_dict,
    in_android_archive_dogfood = _in_android_archive_dogfood,
    in_android_archive_excluded_deps_denylist = _in_android_archive_excluded_deps_denylist,
    in_android_binary_with_sandboxed_sdks_allowlist = _in_android_binary_with_sandboxed_sdks_allowlist,
    in_android_feature_splits_dogfood = _in_android_feature_splits_dogfood,
    in_android_library_starlark_resource_outputs_rollout = _in_android_library_starlark_resource_outputs_rollout,
    in_android_library_resources_without_srcs = _in_android_library_resources_without_srcs,
    in_android_library_resources_without_srcs_generator_functions = _in_android_library_resources_without_srcs_generator_functions,
    in_android_library_use_aosp_aidl_compiler_allowlist = _in_android_library_use_aosp_aidl_compiler_allowlist,
    in_android_lint_checks_rollout = _in_android_lint_checks_rollout,
    in_android_lint_rollout = _in_android_lint_rollout,
    in_lint_registry_rollout = _in_lint_registry_rollout,
    in_android_build_stamping_rollout = _in_android_build_stamping_rollout,
    in_android_test_lockdown_allowlist = _in_android_test_lockdown_allowlist,
    in_databinding_allowed = _in_databinding_allowed,
    in_dex2oat_opts = _in_dex2oat_opts,
    in_install_apps_in_data = _in_install_apps_in_data,
    in_local_test_multi_proto = _in_local_test_multi_proto,
    in_test_to_instrument_test_rollout = _in_test_to_instrument_test_rollout,
    in_allow_resource_conflicts = _in_allow_resource_conflicts,
    in_partial_jetification_targets = _in_partial_jetification_targets,
    in_android_instrumentation_test_manifest_check_rollout = _in_android_instrumentation_test_manifest_check_rollout,
    in_android_instrumentation_test_prebuilt_test_apk = _in_android_instrumentation_test_prebuilt_test_apk,
    in_baseline_profiles_rollout = _in_baseline_profiles_rollout,
    in_baseline_profiles_optimizer_integration = _in_baseline_profiles_optimizer_integration,
    in_android_apk_to_bundle_features = _in_android_apk_to_bundle_features,
    in_shared_library_resource_linking_allowlist = _in_shared_library_resource_linking_allowlist,
    in_android_binary_min_sdk_version_attribute_allowlist = _in_android_binary_min_sdk_version_attribute_allowlist,
    in_android_binary_raw_access_to_resource_paths_allowlist = _in_android_binary_raw_access_to_resource_paths_allowlist,
    in_android_binary_resource_name_obfuscation_opt_out_allowlist = _in_android_binary_resource_name_obfuscation_opt_out_allowlist,
    in_allow_proguard_apply_mapping = _in_allow_proguard_apply_mapping,
    use_r8 = _use_r8,
    in_disable_optimizing_dexer = _in_disable_optimizing_dexer,
    in_force_final_android_binary_resources = _in_force_final_android_binary_resources,
    in_resource_shrinking_in_optimizer = _in_resource_shrinking_in_optimizer,
    in_record_desugaring_rollout = _in_record_desugaring_rollout,
    in_stamp_signing_rollout = _in_stamp_signing_rollout,
)

# Visible for testing
testing = struct(
    matches = matches,
    make_dict = make_dict,
)
