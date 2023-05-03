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

load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
load("//rules:providers.bzl", "StarlarkApkInfo")

ATTRS = _attrs.add(
    dict(
        deps = attr.label_list(
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
            doc = (
                "The list of other libraries to link against. Permitted library types " +
                "are: `android_library`, `java_library` with `android` constraint and " +
                "`cc_library` wrapping or producing `.so` native libraries for the " +
                "Android target platform."
            ),
        ),
        enable_data_binding = attr.bool(
            default = False,
            doc = (
                "If true, this rule processes [data binding]" +
                "(https://developer.android.com/topic/libraries/data-binding) " +
                "expressions in layout resources included through the [resource_files]" +
                "(https://docs.bazel.build/versions/main/be/android.html#android_binary.resource_files) " +
                "attribute. Without this setting, data binding expressions produce build " +
                "failures. To build an Android app with data binding, you must also do the following:" +
                "\n\n1. Set this attribute for all Android rules that transitively depend on " +
                "this one. This is because dependers inherit the rule's data binding " +
                "expressions through resource merging. So they also need to build with " +
                "data binding to parse those expressions." +
                "\n\n2. Add a `deps =` entry for the data binding runtime library to all targets " +
                "that set this attribute. The location of this library depends on your depot setup."
            ),
        ),
        exported_plugins = attr.label_list(
            providers = [
                [JavaPluginInfo],
            ],
            cfg = "exec",
            doc = (
                "The list of [java_plugin](https://docs.bazel.build/versions/main/be/java.html#java_plugin)s " +
                "(e.g. annotation processors) to export to libraries that directly depend on this library. " +
                "The specified list of `java_plugin`s will be applied to any library which directly depends on " +
                "this library, just as if that library had explicitly declared these labels in " +
                "[plugins](#android_library-plugins)."
            ),
        ),
        exports = attr.label_list(
            providers = [
                [CcInfo],
                [JavaInfo],
            ],
            doc = (
                "The closure of all rules reached via `exports` attributes are considered " +
                "direct dependencies of any rule that directly depends on the target with " +
                "`exports`. The `exports` are not direct deps of the rule they belong to."
            ),
        ),
        exports_manifest = _attrs.tristate.create(
            default = _attrs.tristate.no,
            doc = (
                "Whether to export manifest entries to `android_binary` targets that " +
                "depend on this target. `uses-permissions` attributes are never exported."
            ),
        ),
        idl_import_root = attr.string(
            doc = (
                "Package-relative path to the root of the java package tree containing idl " +
                "sources included in this library. This path will be used as the import root " +
                "when processing idl sources that depend on this library." +
                "\n\n" +
                "When `idl_import_root` is specified, both `idl_parcelables` and `idl_srcs` must " +
                "be at the path specified by the java package of the object they represent " +
                "under `idl_import_root`. When `idl_import_root` is not specified, both " +
                "`idl_parcelables` and `idl_srcs` must be at the path specified by their " +
                "package under a Java root. " +
                "See [examples](#examples)"
            ),
        ),
        idl_parcelables = attr.label_list(
            allow_files = [".aidl"],
            doc = (
                "List of Android IDL definitions to supply as imports. These files will " +
                "be made available as imports for any `android_library` target that depends " +
                "on this library, directly or via its transitive closure, but will not be " +
                "translated to Java or compiled. Only `.aidl` files that correspond directly " +
                "to `.java` sources in this library should be included (e.g., custom " +
                "implementations of Parcelable), otherwise `idl_srcs` should be used." +
                "\n\n" +
                "These files must be placed appropriately for the aidl compiler to find " +
                "them. See the description of [idl_import_root](#android_library-idl_import_root) " +
                "for information about what this means."
            ),
        ),
        idl_preprocessed = attr.label_list(
            allow_files = [".aidl"],
            doc = (
                "List of preprocessed Android IDL definitions to supply as imports. These " +
                "files will be made available as imports for any `android_library` target " +
                "that depends on this library, directly or via its transitive closure, but " +
                "will not be translated to Java or compiled. Only preprocessed `.aidl` " +
                "files that correspond directly to `.java` sources in this library should " +
                "be included (e.g., custom implementations of Parcelable), otherwise use " +
                "`idl_srcs` for Android IDL definitions that need to be translated to Java " +
                "interfaces and use `idl_parcelable` for non-preprocessed AIDL files."
            ),
        ),
        idl_srcs = attr.label_list(
            allow_files = [".aidl"],
            doc = (
                "List of Android IDL definitions to translate to Java interfaces. After " +
                "the Java interfaces are generated, they will be compiled together with " +
                "the contents of `srcs`. These files will be made available as imports " +
                "for any `android_library` target that depends on this library, directly " +
                "or via its transitive closure." +
                "\n\n" +
                "These files must be placed appropriately for the aidl compiler to find " +
                "them. See the description of [idl_import_root](#android_library-idl_import_root) " +
                "for information about what this means."
            ),
        ),
        idl_uses_aosp_compiler = attr.bool(
            default = False,
            doc = (
                "Use the upstream AOSP compiler to generate Java files out of `idl_srcs`." +
                "The upstream AOSP compiler provides several new language features that the " +
                "Google3-only compiler doesn't provide. For example: structured parcelables, " +
                "unions, enums, nested type declarations, constant expressions, annotations, " +
                "and more. " +
                "See [AIDL Doc](https://source.android.com/docs/core/architecture/aidl/overview) " +
                "for more details. " +
                "Note: the use of the AOSP compiler in google3 is restricted due to performance " +
                "considerations. This should not be broadly used unless these features are " +
                "strictly required."
            ),
        ),
        idlopts = attr.string_list(
            mandatory = False,
            allow_empty = True,
            default = [],
            doc = (
                "Add these flags to the AIDL compiler command."
            ),
        ),
        neverlink = attr.bool(
            default = False,
            doc = (
                "Only use this library for compilation and not at runtime. The outputs " +
                "of a rule marked as neverlink will not be used in `.apk` creation. " +
                "Useful if the library will be provided by the runtime environment during execution."
            ),
        ),
        proguard_specs = attr.label_list(
            allow_files = True,
            doc = (
                "Files to be used as Proguard specification. These will describe the set " +
                "of specifications to be used by Proguard. If specified, they will be " +
                "added to any `android_binary` target depending on this library. The " +
                "files included here must only have idempotent rules, namely -dontnote, " +
                "-dontwarn, assumenosideeffects, and rules that start with -keep. Other " +
                "options can only appear in `android_binary`'s proguard_specs, to " +
                "ensure non-tautological merges."
            ),
        ),
        resource_apks = attr.label_list(
            allow_rules = ["apk_import"],
            providers = [
                [StarlarkApkInfo],
            ],
            doc = (
                "List of resource only apks to link against."
            ),
        ),
        srcs = attr.label_list(
            allow_files = [".java", ".srcjar"],
            doc = (
                "The list of `.java` or `.srcjar` files that are processed to create the " +
                "target. `srcs` files of type `.java` are compiled. For *readability's " +
                "sake*, it is not good to put the name of a generated `.java` source " +
                "file into the `srcs`. Instead, put the depended-on rule name in the `srcs`, " +
                "as described below." +
                "\n\n" +
                "`srcs` files of type `.srcjar` are unpacked and compiled. (This is useful " +
                "if you need to generate a set of `.java` files with a genrule or build extension.)"
            ),
        ),
        # TODO(b/127517031): Remove these entries once fixed.
        _defined_assets = attr.bool(default = False),
        _defined_assets_dir = attr.bool(default = False),
        _defined_idl_import_root = attr.bool(default = False),
        _defined_idl_parcelables = attr.bool(default = False),
        _defined_idl_srcs = attr.bool(default = False),
        _defined_local_resources = attr.bool(default = False),
        _java_toolchain = attr.label(
            default = Label("//tools/jdk:toolchain_android_only"),
        ),
        # TODO(str): Remove when fully migrated to android_instrumentation_test
        _android_test_migration = attr.bool(default = False),
        _flags = attr.label(
            default = "//rules/flags",
        ),
        _package_name = attr.string(),  # for sending the package name to the outputs callback
    ),
    _attrs.COMPILATION,
    _attrs.DATA_CONTEXT,
    _attrs.ANDROID_TOOLCHAIN_ATTRS,
)
