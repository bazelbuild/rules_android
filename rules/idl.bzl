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

"""Bazel Android IDL library for the Android rules."""

load(":java.bzl", _java = "java")
load(":path.bzl", _path = "path")
load(":utils.bzl", _log = "log")

_AIDL_TOOLCHAIN_MISSING_ERROR = (
    "IDL sources provided without the Android IDL toolchain."
)

_AIDL_JAVA_ROOT_UNDETERMINABLE_ERROR = (
    "Cannot determine java/javatests root for import %s."
)

IDLContextInfo = provider(
    doc = "Contains data from processing Android IDL.",
    fields = dict(
        idl_srcs = "List of IDL sources",
        idl_import_root = "IDL import root",
        idl_java_srcs = "List of IDL Java sources",
        idl_deps =
            "List of IDL targets required for Java compilation, Proguard, etc.",
        providers = "The list of all providers to propagate.",
    ),
)

def _gen_java_from_idl(
        ctx,
        out_idl_java_src = None,
        idl_src = None,
        transitive_idl_import_roots = [],
        transitive_idl_imports = [],
        transitive_idl_preprocessed = [],
        aidl = None,
        aidl_lib = None,
        aidl_framework = None):
    args = ctx.actions.args()
    args.add("-b")
    args.add_all(transitive_idl_import_roots, format_each = "-I%s")
    args.add(aidl_framework, format = "-p%s")
    args.add_all(transitive_idl_preprocessed, format_each = "-p%s")
    args.add(idl_src)
    args.add(out_idl_java_src)

    ctx.actions.run(
        executable = aidl,
        arguments = [args],
        inputs = depset(
            [aidl_framework],
            transitive = [
                aidl_lib.files,
                transitive_idl_imports,
                transitive_idl_preprocessed,
            ],
        ),
        outputs = [out_idl_java_src],
        mnemonic = "AndroidIDLGenerate",
        progress_message = "Android IDL generation %s" % idl_src.path,
    )

def _get_idl_import_root_path(
        package,
        idl_import_root,
        idl_file_root_path):
    package_path = _path.relative(
        idl_file_root_path,
        package,
    )
    return _path.relative(
        package_path,
        idl_import_root,
    )

def _collect_unique_idl_import_root_paths(
        package,
        idl_import_root,
        idl_imports):
    idl_import_roots = dict()
    for idl_import in idl_imports:
        idl_import_roots[_get_idl_import_root_path(
            package,
            idl_import_root,
            idl_import.root.path,
        )] = True
    return sorted(idl_import_roots.keys())

def _collect_unique_java_roots(idl_imports):
    idl_import_roots = dict()
    for idl_import in idl_imports:
        java_root = _java.root(idl_import.path)
        if not java_root:
            _log.error(_AIDL_JAVA_ROOT_UNDETERMINABLE_ERROR % idl_import.path)
        idl_import_roots[java_root] = True
    return sorted(idl_import_roots.keys())

def _determine_idl_import_roots(
        package,
        idl_import_root = None,
        idl_imports = []):
    if idl_import_root == None:
        return _collect_unique_java_roots(idl_imports)
    return _collect_unique_idl_import_root_paths(
        package,
        idl_import_root,
        idl_imports,
    )

def _process(
        ctx,
        idl_srcs = [],
        idl_parcelables = [],
        idl_import_root = None,
        idl_preprocessed = [],
        deps = [],
        exports = [],
        aidl = None,
        aidl_lib = None,
        aidl_framework = None):
    """Processes Android IDL.

    Args:
      ctx: The context.
      idl_srcs: sequence of Files. A list of the aidl source files to be
        processed into Java source files and then compiled. Optional.
      idl_parcelables: sequence of Files. A list of Android IDL definitions to
        supply as imports. These files will be made available as imports for any
        android_library target that depends on this library, directly or via its
        transitive closure, but will not be translated to Java or compiled.

        Only .aidl files that correspond directly to .java sources in this library
        should be included (e.g. custom implementations of Parcelable), otherwise
        idl_srcs should be used.

        These files must be placed appropriately for the aidl compiler to find
        them. See the description of idl_import_root for information about what
        this means. Optional.
      idl_import_root: string. Package-relative path to the root of the java
        package tree containing idl sources included in this library. This path
        will be used as the import root when processing idl sources that depend on
        this library.

        When idl_import_root is specified, both idl_parcelables and idl_srcs must
        be at the path specified by the java package of the object they represent
        under idl_import_root. When idl_import_root is not specified, both
        idl_parcelables and idl_srcs must be at the path specified by their
        package under a Java root. Optional.
      idl_preprocessed: sequence of Files. A list of preprocessed Android IDL
        definitions to supply as imports. These files will be made available as
        imports for any android_library target that depends on this library,
        directly or via its transitive closure, but will not be translated to
        Java or compiled.

        Only preprocessed .aidl files that correspond directly to .java sources
        in this library should be included (e.g. custom implementations of
        Parcelable), otherwise use idl_srcs for Android IDL definitions that
        need to be translated to Java interfaces and use idl_parcelable for
        non-preprcessed AIDL files. Optional.
      deps: sequence of Targets. A list of dependencies. Optional.
      exports: sequence of Targets. A list of exports. Optional.
      aidl: Target. A target pointing to the aidl executable to be used for
        Java code generation from *.idl source files. Optional, unless idl_srcs
        are supplied.
      aidl_lib: Target. A target pointing to the aidl_lib library required
        during Java compilation when Java code is generated from idl sources.
        Optional, unless idl_srcs are supplied.
      aidl_framework: Target. A target pointing to the aidl framework. Optional,
        unless idl_srcs are supplied.

    Returns:
      A IDLContextInfo provider.
    """
    if idl_srcs and not (aidl and aidl_lib and aidl_framework):
        _log.error(_AIDL_TOOLCHAIN_MISSING_ERROR)

    transitive_idl_import_roots = []
    transitive_idl_imports = []
    transitive_idl_preprocessed = []
    for dep in deps + exports:
        transitive_idl_import_roots.append(dep.transitive_idl_import_roots)
        transitive_idl_imports.append(dep.transitive_idl_imports)
        transitive_idl_preprocessed.append(dep.transitive_idl_preprocessed)

    idl_java_srcs = []
    for idl_src in idl_srcs:
        idl_java_src = ctx.actions.declare_file(
            ctx.label.name + "_aidl/" + idl_src.path.replace(".aidl", ".java"),
        )
        idl_java_srcs.append(idl_java_src)
        _gen_java_from_idl(
            ctx,
            out_idl_java_src = idl_java_src,
            idl_src = idl_src,
            transitive_idl_import_roots = depset(
                _determine_idl_import_roots(
                    ctx.label.package,
                    idl_import_root,
                    idl_parcelables + idl_srcs,
                ),
                transitive = transitive_idl_import_roots,
                order = "preorder",
            ),
            transitive_idl_imports = depset(
                idl_parcelables + idl_srcs,
                transitive = transitive_idl_imports,
                order = "preorder",
            ),
            transitive_idl_preprocessed = depset(
                transitive = transitive_idl_preprocessed,
            ),
            aidl = aidl,
            aidl_lib = aidl_lib,
            aidl_framework = aidl_framework,
        )

    return IDLContextInfo(
        idl_srcs = idl_srcs,
        idl_import_root = idl_import_root,
        idl_java_srcs = idl_java_srcs,
        idl_deps = [aidl_lib] if idl_java_srcs else [],
        providers = [
            # TODO(b/146216105): Make this a Starlark provider.
            AndroidIdlInfo(
                depset(
                    _determine_idl_import_roots(
                        ctx.label.package,
                        idl_import_root,
                        idl_parcelables + idl_srcs + idl_preprocessed,
                    ),
                    transitive = transitive_idl_import_roots,
                    order = "preorder",
                ),
                depset(
                    idl_parcelables + idl_srcs + idl_preprocessed,
                    transitive = transitive_idl_imports,
                    order = "preorder",
                ),
                depset(),  # TODO(b/146216105): Delete this field once in Starlark.
                depset(idl_preprocessed, transitive = transitive_idl_preprocessed),
            ),
        ],
    )

idl = struct(
    process = _process,
)

# Visible for testing.
testing = struct(
    get_idl_import_root_path = _get_idl_import_root_path,
)
