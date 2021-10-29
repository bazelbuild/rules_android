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
        default = "@androidsdk//:aapt2_binary",
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
        default = "@bazel_tools//tools/android:aar_embedded_jars_extractor",
        executable = True,
    ),
    aar_embedded_proguard_extractor = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@bazel_tools//tools/android:aar_embedded_proguard_extractor",
        executable = True,
    ),
    aar_native_libs_zip_creator = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@bazel_tools//tools/android:aar_native_libs_zip_creator",
        executable = True,
    ),
    aar_resources_extractor = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@bazel_tools//tools/android:aar_resources_extractor",
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
    android_archive_manifest_package_validator = attr.label(
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
        default = "@androidsdk//:fail",  # TODO: "//src/tools/ak", needs Go
        executable = True,
    ),
    android_resources_busybox = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@bazel_tools//src/tools/android/java/com/google/devtools/build/android:ResourceProcessorBusyBox_deploy.jar",
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
    data_binding_annotation_processor = attr.label(
        cfg = "exec",
        default = "@//tools/android:compiler_annotation_processor",  # TODO: processor rules should be moved into rules_android
    ),
    data_binding_annotation_template = attr.label(
        default = "//rules:data_binding_annotation_template.txt",
        allow_files = True,
    ),
    data_binding_exec = attr.label(
        cfg = "exec",
        default = "@bazel_tools//tools/android:databinding_exec",
        executable = True,
    ),
    desugar_java8_extra_bootclasspath = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@bazel_tools//tools/android:desugar_java8_extra_bootclasspath",
        executable = True,
    ),
    idlclass = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@bazel_tools//tools/android:IdlClass",  # _deploy.jar?
        executable = True,
    ),
    import_deps_checker = attr.label(
        allow_files = True,
        cfg = "exec",
        default = "@android_tools//:ImportDepsChecker_deploy.jar",
        executable = True,
    ),
    jacocorunner = attr.label(
        default = "@androidsdk//:fail",
    ),
    java_stub = attr.label(
        allow_files = True,
        # used in android_local_test
        default = "@androidsdk//:fail",  # TODO: java_stub_template.txt gets embedded in bazel's jar, need a copy in @bazel_tools or similar
    ),
    jdeps_tool = attr.label(
        allow_files = True,
        cfg = "exec",
        # used in android_local_test
        default = "@androidsdk//:fail",  # TODO: "//src/tools/jdeps", needs Go
        executable = True,
    ),
    proguard_allowlister = attr.label(
        cfg = "exec",
        default = "@bazel_tools//tools/jdk:proguard_whitelister",
        executable = True,
    ),
    proto_map_generator = attr.label(
        cfg = "exec",
        default = "@androidsdk//:fail",
        allow_files = True,
        executable = True,
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
    testsupport = attr.label(
        default = "@androidsdk//:fail",
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
)

def _impl(ctx):
    return [platform_common.ToolchainInfo(
        **{name: getattr(ctx.attr, name) for name in _ATTRS.keys()}
    )]

android_toolchain = rule(
    implementation = _impl,
    attrs = _ATTRS,
)
