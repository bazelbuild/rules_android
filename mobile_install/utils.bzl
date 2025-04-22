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
"""Utilities for by the Mobile-Install aspect."""

load("//rules:min_sdk_version.bzl", _min_sdk_version = "min_sdk_version")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//rules/flags:flags.bzl", "flags")
load("@rules_java//java/common:java_common.bzl", "java_common")
# Copybara: placeholder for GeneratedExtensionRegistryInfo load
load(":constants.bzl", "constants")

visibility(PROJECT_VISIBILITY)

_PACKAGE_NAME_EXTRACTION_SCRIPT = """
    #!/bin/bash
    set -e  # exit on failure
    umask 022  # set default file/dir creation mode to 755

    base=$(pwd)
    $base/{aapt_tool} dump badging {apk_path} | awk -v FS="'" '/package: name=/{{print $2}}' > {output_file}
    """

def create_flag_file(ctx, flag_file, **flags):
    """Creates flag file artifact from keyword args (named flags).

    The flags variable is a map where the key/value pairs are used as flag/value
    pairs. Each flag/value pair is outputted onto its own line. List and set
    values will have their contents joined into comma separated string.

    Example:

          flags = {"a": 1, "b": [2, 3, 4]}

      is converted to a flag file with the following contents:

          --a=1
          --b=2,3,4

    Args:
      ctx: Context.
      flag_file: File artifact to output contents.
      **flags: Is the kwargs where the key/value pairs are treated as flag/value
        pairs. Values can be primitives, list or sets. dicts are not supported.
    """
    content = []
    for flag, value in flags.items():
        if not value:
            continue

        # join set or list values into a comma separted string.
        value_type = type(value)
        if constants.TYPE_LIST == value_type:
            value = ",".join(value)
        elif constants.TYPE_DEPSET == value_type:
            value = ",".join(value.to_list())
        elif constants.TYPE_DICT == value_type:
            fail("Error, dict is an unsupported value type: " + str(value_type))
        content.append("--%s=%s\n" % (flag, value))
    ctx.actions.write(output = flag_file, content = "".join(content))

def isolated_declare_file(ctx, name, sibling = None):
    """A helper method to ensure creating different outputs for each version of the aspect.

    Wraps ctx.actions.declare_file to add a "mi_test/" prefix to each output file if the
    _mi_is_test attr is True.

    Args:
      ctx: The context.
      name: Name of the file.
      sibling: Provides a location to create the new file.

    Returns:
      A new file.
    """

    return ctx.actions.declare_file(
        "mi_test/" + name if hasattr(ctx.attr, "_mi_is_test") and ctx.attr._mi_is_test else name,
        sibling = sibling,
    )

def declare_file(ctx, name, sibling = None):
    """A helper method for creating files for the transforms uniquely and safely.

    Wraps ctx.actions.declare_file method, but provides additional checks around
    the optional sibling parameter. Since transform functions run on a varied set
    of inputs, it is highly probable that some proposed siblings may be invalid to
    be used as such. Hence, this method provides a fallback mechanism keep files
    unique when an invalid sibling is given.

    Args:
      ctx: The context.
      name: Name of the file.
      sibling: Provides a location to create the new file.

    Returns:
      A new file.
    """

    # The sibling file must be owned by the same label as the file that is being
    # created (ctx.label).
    #
    # For example:
    #
    #   //foo/bar:myapp - android_binary
    #     deps = [//foo/bar:quux_lite_proto]
    #
    #   //com/common:quux_lite_proto - java_lite_proto_library
    #     deps = [//com/common:quuz_proto, //com/common:corge_proto]
    #     exports jar-> [quuz_lite.jar, corge_lite.jar]
    #
    #   //com/common:quuz_proto - proto_library
    #   //com/common:corge_proto - proto_library
    #
    # Here, quux_lite_proto rule in its files provider, provides both the
    # quuz_lite.jar and corge_lite.jar neither of which were produced by the rule
    # itself, which then causes the sibling (jar) not to be valid, because the
    # owner (or owners in this case) are the proto_library rules.
    #
    # When the sibling is invalid, we create the new file under the context of the
    # current label.name and prepend the label of the proposed sibling's owners.
    # This is done to guarantee the uniqueness of the new file graph-wide.
    if sibling and sibling.owner and sibling.owner != ctx.label:
        name = (ctx.label.name + "_mi/" + sibling.owner.package.replace("/", "_") + "/" + name)
        sibling = None  # Remove the invalid sibling.
    return isolated_declare_file(ctx, name, sibling = sibling)

def host_jvm_path(ctx):
    """Returns the path to the host JVM.

    Args:
      ctx: The context.

    Returns:
      The execpath to the "java" binary.
    """
    return str(ctx.attr._host_java_runtime[java_common.JavaRuntimeInfo].java_executable_exec_path)

def dex(ctx, jar, out_dex_shards, deps = None):
    """Desugar, dex and shard a Jar.

    Args:
      ctx: The context.
      jar: The Jar to Dex.
      out_dex_shards: A list of files to output. When more than on file
        is given, will shard the Jar to Dex across all given files in a
        deterministic manner.
      deps: The list of dependencies for the Jar being desugared.
    """
    min_sdk = _min_sdk_version.get(ctx)
    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "-flagfile=%s", use_always = True)

    args.add("-android_jar", first(ctx.files._android_sdk))
    if deps:
        args.add_joined("-classpath", deps, join_with = ",")
    args.add("-desugar_core_libs", "True")

    # Unconditionally add -desugared_lib_config. This matches the behavior of tools/android/d8_desugar.sh.
    args.add("-desugared_lib_config", ctx.file._desugared_lib_config)

    args.add("-min_sdk_version", min_sdk)
    args.add("-in", jar)
    args.add_joined("-out", out_dex_shards, join_with = ",")

    java_runtime = ctx.attr._mi_host_javabase[java_common.JavaRuntimeInfo]
    java = java_runtime.java_executable_exec_path

    # Performance-related JVM flags for the desugar tool.
    jvm_flags = [
        # b/71513487
        "-XX:+TieredCompilation",
        "-XX:TieredStopAtLevel=1",
        "-Xms8g",
        "-Xmx8g",
    ]

    ctx.actions.run(
        executable = java,
        tools = [ctx.executable._desugar_dex_sharding],
        arguments = jvm_flags + ["-jar", ctx.executable._desugar_dex_sharding.path, args],
        inputs = depset(
            ctx.files._android_sdk + ctx.files._mi_host_javabase + [jar, ctx.file._desugared_lib_config],
            transitive = [deps] if deps else [],
        ),
        outputs = out_dex_shards,
        mnemonic = "DesugarDexSharding",
        progress_message = "MI Desugar, dex and sharding " + jar.path,
        execution_requirements = {
            "worker-key-mnemonic": "DesugarDexSharding",
            "supports-workers": "1",
            "supports-multiplex-workers": "1",
        },
        toolchain = None,
    )

def extract_jar_resources(ctx, jar, out_resources):
    """Extracts the non-class files from the Jars.

    Args:
      ctx: The context.
      jar: The Jar to extract resources from.
      out_resources: The file to output the resources from the Jar.
    """

    # TODO(djwhang): Make another action that strips the resources from the Jar.
    # This makes the Jar itself a cacheable, even though resources changed.
    # Filters .class and directories from Jar files
    ctx.actions.run_shell(
        command = (
            'cp $2 $1; chmod 644 $1; zip -qd $1 "*.class" "*/";' + "err=$?; if" +
            " [ 0 -ne $err ] && [ 12 -ne $err ]; then exit ${err}; fi"
        ),
        arguments = [out_resources.path, jar.path],
        inputs = [jar],
        outputs = [out_resources],
        mnemonic = "ExtractJarResources",
        progress_message = "MI Extracting resources from " + jar.path,
    )

def first(collection, allow_empty = False):
    """Returns the first item in the collection.

    Args:
      collection: The container object to extract data from.
      allow_empty: Whether to allow empty containers.

    Returns:
      The first object in the collection.
    """
    for i in collection:
        return i
    if not allow_empty:
        fail("Error, the collection is empty.")
    return None

def only(collection, allow_empty = False):
    """Returns the only item in the collection.

    Args:
      collection: The container object to extract data from.
      allow_empty: Whether to allow empty containers.

    Returns:
      The _only_ object in the container (size must be 1 or 0 if allow_empty == True).
    """
    if len(collection) > 1:
        fail("Error, the collection has more than 1 item.")
    return first(collection, allow_empty)

def make_substitutions(**kwargs):
    return {"%%%s%%" % key: val for key, val in kwargs.items()}

def merge_dex_shards(
        ctx,
        dex_archives,
        out_dex_zip):
    """Merge dex archive zips into a single archive with dex files merged up to dex file limits.

    Args:
      ctx: The context.
      dex_archives: A list or depset of Dex zip archives.
      out_dex_zip: The file to output.
    """
    args = ctx.actions.args()


    args.add("--multidex", "best_effort")
    args.add("--output", out_dex_zip.path)
    args.add_all(dex_archives, before_each = "--input")
    args.use_param_file(param_file_arg = "@%s", use_always = True)
    args.set_param_file_format("multiline")

    ctx.actions.run(
        executable = ctx.executable._dexmerger,
        arguments = [args],
        tools = [],
        inputs = dex_archives,
        outputs = [out_dex_zip],
        mnemonic = "DexMerge",
        progress_message = "MI Merging dexes",
        toolchain = None,
    )

def strip_r(ctx, jar, out_jar):
    """Strips the R from the Jar.

    Args:
      ctx: The context.
      jar: The Jar to strip.
      out_jar: The file to output the stripped Jar.
    """
    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "--flagfile=%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add("-filter_r")
    args.add("-in", jar)
    args.add("-out", out_jar)

    ctx.actions.run(
        executable = ctx.executable._android_kit,
        arguments = ["repack", args],
        inputs = [jar],
        outputs = [out_jar],
        mnemonic = "StripR",
        progress_message = "MI Stripping R from " + jar.path,
        toolchain = None,
    )

def _extract_package_name(ctx, apk, package_name_output_file):
    """Extracts the package name from an apk using aapt and writes into output file

    Args:
      ctx: The context.
      apk: The apk.
      package_name_output_file:  The file to output the package_name.
    """

    cmd = _PACKAGE_NAME_EXTRACTION_SCRIPT.format(
        apk_path = apk.path,
        aapt_tool = ctx.executable._aapt2.path,
        output_file = package_name_output_file.path,
    )

    ctx.actions.run_shell(
        command = cmd,
        tools = [ctx.executable._aapt2],
        inputs = [apk],
        outputs = [package_name_output_file],
        mnemonic = "ExtractPackageName",
        progress_message = "MI Extracts the package name from %s" % apk.path,
    )

def _get_extension_registry_class_jar(target):
    class_jar = None

    return class_jar

utils = struct(
    create_flag_file = create_flag_file,
    declare_file = declare_file,
    isolated_declare_file = isolated_declare_file,
    dex = dex,
    extract_jar_resources = extract_jar_resources,
    extract_package_name = _extract_package_name,
    first = first,
    get_extension_registry_class_jar = _get_extension_registry_class_jar,
    host_jvm_path = host_jvm_path,
    make_substitutions = make_substitutions,
    merge_dex_shards = merge_dex_shards,
    only = only,
    strip_r = strip_r,
)
