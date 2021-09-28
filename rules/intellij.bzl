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

"""Common methods for use by the IntelliJ Aspect."""

load(":java.bzl", _java = "java")
load(":utils.bzl", _utils = "utils")

def _extract_idl_jars(
        ctx,
        idl_java_srcs = [],
        jar = None,
        manifest_proto = None,
        out_srcjar = None,
        out_jar = None,
        idlclass = None,
        host_javabase = None):
    """Extracts the idl class and src jars."""
    args = ctx.actions.args()
    args.add("--class_jar", jar)
    args.add("--manifest_proto", manifest_proto)
    args.add("--output_class_jar", out_jar)
    args.add("--output_source_jar", out_srcjar)
    args.add("--temp_dir", out_jar.dirname)
    args.add_all(idl_java_srcs)

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = idlclass,
        arguments = [args],
        inputs = idl_java_srcs + [jar, manifest_proto],
        outputs = [out_srcjar, out_jar],
        mnemonic = "AndroidIdlJars",
        progress_message = "Building idl jars %s" % out_jar.path,
    )

def _make_android_ide_info(
        ctx,
        idl_ctx = None,
        resources_ctx = None,
        defines_resources = False,
        java_package = None,
        manifest = None,
        merged_manifest = None,
        resources_apk = None,
        idl_import_root = None,
        idl_srcs = [],
        idl_java_srcs = [],
        java_info = None,
        r_jar = None,
        signed_apk = None,
        aar = None,
        apks_under_test = [],
        native_libs = dict(),
        idlclass = None,
        host_javabase = None):
    # TODO(b/154513292): Clean up bad usages of context objects.
    if idl_ctx:
        idl_import_root = idl_ctx.idl_import_root
        idl_srcs = idl_ctx.idl_srcs
        idl_java_srcs = idl_ctx.idl_java_srcs
    if resources_ctx:
        defines_resources = resources_ctx.defines_resources
        merged_manifest = resources_ctx.merged_manifest
        resources_apk = resources_ctx.resources_apk

    if not defines_resources:
        java_package = None
        merged_manifest = None

    # Extracts idl related classes from the jar and creates a src jar
    # for the idl generated java.
    idl_jar = None
    idl_srcjar = None

    # TODO(djwhang): JavaInfo.outputs.jar.manifest_proto is not created by
    # Kotlin compile. Determine if this is the same manifest_proto produced
    # by turbine, this could be pulled during annotation processing.
    jar = _utils.only(java_info.outputs.jars)
    if idl_java_srcs and jar.manifest_proto:
        idl_jar = ctx.actions.declare_file("lib%s-idl.jar" % ctx.label.name)
        idl_srcjar = \
            ctx.actions.declare_file("lib%s-idl.srcjar" % ctx.label.name)

        jar = _utils.only(java_info.outputs.jars)
        _extract_idl_jars(
            ctx,
            idl_java_srcs = idl_java_srcs,
            jar = jar.class_jar,
            manifest_proto = jar.manifest_proto,
            out_jar = idl_jar,
            out_srcjar = idl_srcjar,
            idlclass = idlclass,
            host_javabase = host_javabase,
        )

    return AndroidIdeInfo(
        java_package,
        manifest,
        merged_manifest,
        idl_import_root,
        idl_srcs,
        idl_java_srcs,
        idl_srcjar,
        idl_jar,
        defines_resources,
        r_jar,
        resources_apk,
        signed_apk,
        aar,
        apks_under_test,
        native_libs,
    )

def _make_legacy_android_provider(android_ide_info):
    # Create the ClassJar "object" for the target.android.idl.output field.
    if android_ide_info.idl_class_jar:
        idl_class_jar = struct(
            class_jar = android_ide_info.idl_class_jar,
            ijar = None,
            source_jar = android_ide_info.idl_source_jar,
        )
    else:
        idl_class_jar = None

    return struct(
        aar = android_ide_info.aar,
        apk = android_ide_info.signed_apk,
        apks_under_test = android_ide_info.apks_under_test,
        defines_resources = android_ide_info.defines_android_resources,
        idl = struct(
            import_root = android_ide_info.idl_import_root,
            sources = android_ide_info.idl_srcs,
            generated_java_files = android_ide_info.idl_generated_java_files,
            output = idl_class_jar,
        ),
        java_package = android_ide_info.java_package,
        manifest = android_ide_info.manifest,
        merged_manifest = android_ide_info.generated_manifest,
        native_libs = android_ide_info.native_libs,
        resource_apk = android_ide_info.resource_apk,
        resource_jar = android_ide_info.resource_jar,
    )

intellij = struct(
    make_android_ide_info = _make_android_ide_info,
    make_legacy_android_provider = _make_legacy_android_provider,
)

# Only visible for testing.
testing = struct(
    extract_idl_jars = _extract_idl_jars,
)
