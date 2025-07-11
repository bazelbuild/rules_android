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
"""Android toolchain."""

_ATTRS = dict(
    aapt2 = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@androidsdk//:aapt2",
    ),
    aar_import_checks = attr.label(
        allow_single_file = True,
        cfg = "exec",
        default = "//src/validations/aar_import_checks",
        executable = True,
    ),
    aar_embedded_jars_extractor = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "//tools/android:aar_embedded_jars_extractor",
        executable = True,
    ),
    aar_embedded_proguard_extractor = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "//tools/android:aar_embedded_proguard_extractor",
        executable = True,
    ),
    aar_native_libs_zip_creator = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "//tools/android:aar_native_libs_zip_creator",
        executable = True,
    ),
    aar_resources_extractor = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "//tools/android:aar_resources_extractor",
        executable = True,
    ),
    adb = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@androidsdk//:platform-tools/adb",
        executable = True,
    ),
    add_g3itr_xslt = attr.label(
        cfg = "exec",
        default = Label("//tools/android/xslt:add_g3itr.xslt"),
        allow_files = True,
    ),
    android_archive_jar_optimization_inputs_validator = attr.label(
        allow_files = True,
        default = "@androidsdk//:fail",
        cfg = "exec",
        executable = True,
    ),
    android_archive_packages_validator = attr.label(
        allow_files = True,
        default = "@androidsdk//:fail",
        cfg = "exec",
        executable = True,
    ),
    android_kit = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "//src/tools/ak",
        executable = True,
    ),
    android_resources_busybox = attr.label(
        allow_files = True,
        cfg = "exec",
        default = Label("//src/tools/java/com/google/devtools/build/android:ResourceProcessorBusyBox_deploy.jar"),
        executable = True,
    ),
    apk_to_bundle_tool = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@androidsdk//:fail",
        executable = True,
    ),
    bundletool = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "//tools/android:bundletool_deploy.jar",
        executable = True,
    ),
    bundletool_module_builder = attr.label(
        allow_single_file = True,
        cfg = "exec",
        default = "//src/tools/bundletool_module_builder",
        executable = True,
    ),
    centralize_r_class_tool = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@androidsdk//:fail",
        executable = True,
    ),
    data_binding_annotation_processor = attr.label(
        cfg = "exec",
        default = "//tools/android:compiler_annotation_processor",
    ),
    data_binding_annotation_template = attr.label(
        default = "//rules:data_binding_annotation_template.txt",
        allow_files = True,
    ),
    data_binding_exec = attr.label(
        cfg = "exec",
        default = "//tools/android:databinding_exec",
        executable = True,
    ),
    desugar = attr.label(
        cfg = "exec",
        default = Label("//tools/android:desugar_java8"),
        executable = True,
    ),
    desugar_java8_extra_bootclasspath = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "//tools/android:desugar_java8_extra_bootclasspath",
        executable = True,
    ),
    desugar_globals = attr.label(
        cfg = "exec",
        allow_single_file = True,
        default = Label("//tools/android:desugar.globals"),
    ),
    desugar_globals_dex_archive = attr.label(
        cfg = "target",
        allow_single_file = True,
        default = "//tools/android:desugar_globals_dex_archive",
    ),
    desugar_globals_jar = attr.label(
        cfg = "exec",
        default = Label("@androidsdk//:fail"),
    ),
    dexbuilder = attr.label(
        cfg = "exec",
        default = Label("//tools/android:dexbuilder"),
        executable = True,
    ),
    dexbuilder_after_proguard = attr.label(
        cfg = "exec",
        default = Label("//tools/android:dexbuilder_after_proguard"),
        executable = True,
    ),
    dexmerger = attr.label(
        cfg = "exec",
        default = Label("//tools/android:dexmerger"),
        executable = True,
    ),
    dexsharder = attr.label(
        cfg = "exec",
        default = Label("//tools/android:dexsharder"),
        executable = True,
    ),
    idlclass = attr.label(
        allow_files = True,
        cfg = "exec",
        default = Label("//src/tools/java/com/google/devtools/build/android/idlclass:IdlClass_deploy.jar"),
        executable = True,
    ),
    import_deps_checker = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@android_tools//:ImportDepsChecker_deploy.jar",
        executable = True,
    ),
    jacocorunner = attr.label(
        default = "@remote_java_tools//:jacoco_coverage_runner",
    ),
    java_stub = attr.label(
        allow_files = True,
        # used in android_local_test
        default = "//tools/jdk:java_stub_template.txt",
    ),
    jdeps_tool = attr.label(
        allow_files = True,
        cfg = "exec",
        # used in android_local_test
        default = "//src/tools/jdeps",
        executable = True,
    ),
    merge_baseline_profiles_tool = attr.label(
        default = "@androidsdk//:fail",
        cfg = "exec",
        executable = True,
    ),
    object_method_rewriter = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@androidsdk//:fail",
        executable = True,
    ),
    proguard_allowlister = attr.label(
        cfg = "exec",
        default = "@bazel_tools//tools/jdk:proguard_whitelister",
        executable = True,
    ),
    profgen = attr.label(
        default = "@androidsdk//:fail",
        cfg = "exec",
        executable = True,
    ),
    proto_map_generator = attr.label(
        cfg = "exec",
        default = "@androidsdk//:fail",
        allow_files = True,
        executable = True,
    ),
    r8 = attr.label(
        cfg = "exec",
        default = "//tools/android:r8_deploy.jar",
        executable = True,
        allow_files = True,
    ),
    resource_shrinker = attr.label(
        cfg = "exec",
        default = "//tools/android:resource_shrinker_deploy.jar",
        executable = True,
        allow_files = True,
    ),
    res_v3_dummy_manifest = attr.label(
        allow_files = True,
        default = "//rules:res_v3_dummy_AndroidManifest.xml",
    ),
    res_v3_dummy_r_txt = attr.label(
        allow_files = True,
        default = "//rules:res_v3_dummy_R.txt",
    ),
    robolectric_template = attr.label(
        allow_files = True,
        default = "//rules:robolectric_properties_template.txt",
    ),
    sandboxed_sdk_toolbox = attr.label(
        allow_single_file = True,
        cfg = "exec",
        default = "//src/tools/java/com/google/devtools/build/android/sandboxedsdktoolbox:sandboxed_sdk_toolbox_deploy.jar",
        executable = True,
    ),
    shuffle_jars = attr.label(
        cfg = "exec",
        default = Label("//tools/android:shuffle_jars"),
        executable = True,
    ),
    testsupport = attr.label(
        default = "@bazel_tools//tools/jdk:TestRunner",
    ),
    unzip_tool = attr.label(
        cfg = "exec",
        default = "//toolchains/android:unzip",
        executable = True,
    ),
    xsltproc_tool = attr.label(
        cfg = "exec",
        default = Label("//tools/android/xslt:xslt"),
        allow_files = True,
        executable = True,
    ),
    zip_tool = attr.label(
        cfg = "exec",
        default = "//toolchains/android:zip",
        executable = True,
    ),
    zip_filter = attr.label(
        cfg = "exec",
        default = "//tools/android:zip_filter",
        executable = True,
    ),
    zipper = attr.label(
        allow_single_file = True,
        cfg = "exec",
        default = "@bazel_tools//tools/zip:zipper",
        executable = True,
    ),
    dex_zips_merger = attr.label(
        cfg = "exec",
        default = "//tools/android:merge_dexzips",
        executable = True,
    ),
    java8_legacy_dex = attr.label(
        allow_single_file = True,
        cfg = "exec",
        default = Label("//tools/android:java8_legacy_dex"),
    ),
    build_java8_legacy_dex = attr.label(
        cfg = "exec",
        default = Label("//tools/android:build_java8_legacy_dex"),
        executable = True,
    ),
    dex_list_obfuscator = attr.label(
        cfg = "exec",
        default = "//tools/android:dex_list_obfuscator",
        executable = True,
    ),
    manifest_validation_tool = attr.label(
        cfg = "exec",
        default = Label("//src/validations/validate_manifest"),
        executable = True,
    ),
    resource_extractor = attr.label(
        cfg = "exec",
        default = "//src/tools/java_resource_extractor:resource_extractor",
        executable = True,
    ),
    deploy_info_writer = attr.label(
      allow_single_file = True,
      cfg = "exec",
      default = Label("//src/tools/deploy_info"),
      executable = True,
    ),
    translation_merger = attr.label(
        cfg = "exec",
        default = "@androidsdk//:fail",
        allow_files = True,
        executable = True,
    ),
)

def _impl(ctx):
    return [platform_common.ToolchainInfo(
        **{name: getattr(ctx.attr, name) for name in _ATTRS.keys()}
    )]

android_toolchain = rule(
    implementation = _impl,
    attrs = _ATTRS,
)
