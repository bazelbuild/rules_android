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

"""Bazel Java APIs for the Android rules."""

load(":path.bzl", _path = "path")
load(":utils.bzl", "log")

_ANDROID_CONSTRAINT_MISSING_ERROR = (
    "A list of constraints provided without the 'android' constraint."
)

# TODO(b/283499746): Reduce singlejar memory if possible.
_SINGLEJAR_MEMORY_FOR_DEPLOY_JAR_MB = 1600

def _segment_idx(path_segments):
    """Finds the index of the segment in the path that preceeds the source root.

    Args:
      path_segments: A list of strings, where each string is the segment of a
        filesystem path.

    Returns:
      An index to the path segment that represents the Java segment or -1 if
      none found.
    """
    if _path.is_absolute(path_segments[0]):
        log.error("path must not be absolute: %s" % _path.join(path_segments))

    root_idx = -1
    for idx, segment in enumerate(path_segments):
        if segment in ["java", "javatests", "src", "testsrc"]:
            root_idx = idx
            break
    if root_idx < 0:
        return root_idx

    is_src = path_segments[root_idx] == "src"
    check_maven_idx = root_idx if is_src else -1
    if root_idx == 0 or is_src:
        # Check for a nested root directory.
        for idx in range(root_idx + 1, len(path_segments) - 2):
            segment = path_segments[idx]
            if segment == "src" or (is_src and segment in ["java", "javatests"]):
                next_segment = path_segments[idx + 1]
                if next_segment in ["com", "org", "net"]:
                    root_idx = idx
                elif segment == "src":
                    check_maven_idx = idx
                break

    if check_maven_idx >= 0 and check_maven_idx + 2 < len(path_segments):
        next_segment = path_segments[check_maven_idx + 1]
        if next_segment in ["main", "test"]:
            next_segment = path_segments[check_maven_idx + 2]
            if next_segment in ["java", "resources"]:
                root_idx = check_maven_idx + 2
    return root_idx

def _resolve_package(path):
    """Determines the Java package name from the given path.

    Examples:
        "{workspace}/java/foo/bar/wiz" -> "foo.bar.wiz"
        "{workspace}/javatests/foo/bar/wiz" -> "foo.bar.wiz"

    Args:
      path: A string, representing a file path.

    Returns:
      A string representing a Java package name or None if could not be
      determined.
    """
    path_segments = _path.split(path.partition(":")[0])
    java_idx = _segment_idx(path_segments)
    if java_idx < 0:
        return None
    else:
        return ".".join(path_segments[java_idx + 1:])

def _resolve_package_from_label(
        label,
        custom_package = None):
    """Resolves the Java package from a Label.

    When no legal Java package can be resolved from the label, None will be
    returned unless fallback is specified.

    When a fallback is requested, a not safe for Java compilation package will
    be returned. The fallback value will be derrived by taking the label.package
    and replacing all path separators with ".".
    """
    if custom_package:
        return custom_package

    # For backwards compatibility, also include directories
    # from the label's name
    # Ex: "//foo/bar:java/com/google/baz" is a legal one and
    # results in "com.google"
    label_path = _path.join(
        [label.package] +
        _path.split(label.name)[:-1],
    )
    return _resolve_package(label_path)

def _root(path):
    """Determines the Java root from the given path.

    Examples:
        "{workspace}/java/foo/bar/wiz" -> "{workspace}/java"
        "{workspace}/javatests/foo/bar/wiz" -> "{workspace}/javatests"
        "java/foo/bar/wiz" -> "java"
        "javatests/foo/bar/wiz" -> "javatests"

    Args:
      path: A string, representing a file path.

    Returns:
      A string representing the Java root path or None if could not be
      determined.
    """
    path_segments = _path.split(path.partition(":")[0])
    java_idx = _segment_idx(path_segments)
    if java_idx < 0:
        return None
    else:
        return _path.join(path_segments[0:java_idx + 1])

def _check_for_invalid_java_package(java_package):
    return "-" in java_package or len(java_package.split(".")) < 2

def _invalid_java_package(custom_package, java_package):
    """Checks if the given java package is invalid.

    Only checks if either custom_package or java_package contains the
    illegal character "-" or if they are composed of only one word.
    Only checks java_package if custom_package is an empty string or None.

    Args:
      custom_package: string. Java package given as an attribute to a rule to override
      the java_package.
      java_package: string. Java package inferred from the directory where the BUILD
      containing the rule is.

    Returns:
      A boolean. True if custom_package or java_package contains "-" or is only one word.
      Only checks java_package if custom_package is an empty string or None.
    """
    return (
        (custom_package and _check_for_invalid_java_package(custom_package)) or
        (not custom_package and _check_for_invalid_java_package(java_package))
    )

# The Android specific Java compile.
def _compile_android(
        ctx,
        output_jar,
        output_srcjar = None,
        srcs = [],
        resources = [],
        javac_opts = [],
        r_java = None,
        deps = [],
        exports = [],
        plugins = [],
        exported_plugins = [],
        annotation_processor_additional_outputs = [],
        annotation_processor_additional_inputs = [],
        enable_deps_without_srcs = False,
        neverlink = False,
        constraints = ["android"],
        strict_deps = "Error",
        java_toolchain = None):
    """Compiles the Java and IDL sources for Android.

    Args:
      ctx: The context.
      output_jar: File. The artifact to place the compilation unit.
      output_srcjar: File. The artifact to place the sources of the compilation
        unit. Optional.
      srcs: sequence of Files. A list of files and jars to be compiled.
      resources: sequence of Files. Will be added to the output jar - see
        java_library.resources. Optional.
      javac_opts: sequence of strings. A list of the desired javac options.
        Optional.
      r_java: JavaInfo. The R.jar dependency. Optional.
      deps: sequence of JavaInfo providers. A list of dependencies. Optional.
      exports: sequence of JavaInfo providers. A list of exports. Optional.
      plugins: sequence of JavaPluginInfo providers. A list of plugins. Optional.
      exported_plugins: sequence of JavaPluginInfo providers. A list of exported
        plugins. Optional.
      annotation_processor_additional_outputs: sequence of Files. A list of
        files produced by an annotation processor.
      annotation_processor_additional_inputs: sequence of Files. A list of
        files consumed by an annotation processor.
      enable_deps_without_srcs: Enables the behavior from b/14473160.
      neverlink: Bool. Makes the compiled unit a compile-time only dependency.
      constraints: sequence of Strings. A list of constraints, to constrain the
        target. Optional. By default [].
      strict_deps: string. A string that specifies how to handle strict deps.
        Possible values: 'OFF', 'ERROR','WARN' and 'DEFAULT'. For more details
        see https://docs.bazel.build/versions/master/user-manual.html#flag--strict_java_deps.
        By default 'ERROR'.
      java_toolchain: The java_toolchain Target.

    Returns:
      A JavaInfo provider representing the Java compilation.
    """
    if "android" not in constraints:
        log.error(_ANDROID_CONSTRAINT_MISSING_ERROR)

    if not srcs:
        if deps and enable_deps_without_srcs:
            # TODO(b/122039567): Produces a JavaInfo that exports the deps, but
            # not the plugins. To reproduce the "deps without srcs" bug,
            # b/14473160, behavior in Starlark.
            exports = exports + [
                android_common.enable_implicit_sourceless_deps_exports_compatibility(dep)
                for dep in deps
            ]
        if not exports:
            # Add a "no-op JavaInfo" to propagate the exported_plugins when
            # deps or exports have not been specified by the target and
            # additionally forces java_common.compile method to create the
            # empty output jar and srcjar when srcs have not been specified.
            noop_java_info = java_common.merge([])
            exports = exports + [noop_java_info]

    r_java_info = [r_java] if r_java else []

    java_info = _compile(
        ctx,
        output_jar,
        output_srcjar = output_srcjar,
        srcs = srcs,
        resources = resources,
        javac_opts = javac_opts,
        deps = r_java_info + deps,
        # In native, the JavaInfo exposes two Jars as compile-time deps, the
        # compiled sources and the Android R.java jars. To simulate this
        # behavior, the JavaInfo of the R.jar is also exported.
        exports = r_java_info + exports,
        plugins = plugins,
        exported_plugins = exported_plugins,
        annotation_processor_additional_outputs = (
            annotation_processor_additional_outputs
        ),
        annotation_processor_additional_inputs = (
            annotation_processor_additional_inputs
        ),
        neverlink = neverlink,
        constraints = constraints,
        strict_deps = strict_deps,
        java_toolchain = java_toolchain,
    )
    return java_info

def _compile(
        ctx,
        output_jar,
        output_srcjar = None,
        srcs = [],
        resources = [],
        javac_opts = [],
        deps = [],
        exports = [],
        plugins = [],
        exported_plugins = [],
        annotation_processor_additional_outputs = [],
        annotation_processor_additional_inputs = [],
        neverlink = False,
        constraints = [],
        strict_deps = "Error",
        java_toolchain = None):
    """Compiles the Java and IDL sources for Android.

    Args:
      ctx: The context.
      output_jar: File. The artifact to place the compilation unit.
      output_srcjar: File. The artifact to place the sources of the compilation
        unit. Optional.
      srcs: sequence of Files. A list of files and jars to be compiled.
      resources: sequence of Files. Will be added to the output jar - see
        java_library.resources. Optional.
      javac_opts: sequence of strings. A list of the desired javac options.
        Optional.
      deps: sequence of JavaInfo providers. A list of dependencies. Optional.
      exports: sequence of JavaInfo providers. A list of exports. Optional.
      plugins: sequence of JavaPluginInfo providers. A list of plugins. Optional.
      exported_plugins: sequence of JavaPluginInfo providers. A list of exported
        plugins. Optional.
      annotation_processor_additional_outputs: sequence of Files. A list of
        files produced by an annotation processor.
      annotation_processor_additional_inputs: sequence of Files. A list of
        files consumed by an annotation processor.
      resources: sequence of Files. Will be added to the output jar - see
        java_library.resources. Optional.
      neverlink: Bool. Makes the compiled unit a compile-time only dependency.
      constraints: sequence of Strings. A list of constraints, to constrain the
        target. Optional. By default [].
      strict_deps: string. A string that specifies how to handle strict deps.
        Possible values: 'OFF', 'ERROR','WARN' and 'DEFAULT'. For more details
        see https://docs.bazel.build/versions/master/user-manual.html#flag--strict_java_deps.
        By default 'ERROR'.
      java_toolchain: The java_toolchain Target.

    Returns:
      A JavaInfo provider representing the Java compilation.
    """

    # Split javac opts.
    opts = []
    for opt in javac_opts:
        opts.extend(opt.split(" "))

    # Separate the sources *.java from *.srcjar.
    source_files = []
    source_jars = []
    for src in srcs:
        if src.path.endswith(".srcjar"):
            source_jars.append(src)
        else:
            source_files.append(src)

    return java_common.compile(
        ctx,
        output = output_jar,
        output_source_jar = output_srcjar,
        source_files = source_files,
        source_jars = source_jars,
        resources = resources,
        javac_opts = opts,
        deps = deps,
        exports = exports,
        plugins = plugins,
        exported_plugins = exported_plugins,
        annotation_processor_additional_outputs = (
            annotation_processor_additional_outputs
        ),
        annotation_processor_additional_inputs = (
            annotation_processor_additional_inputs
        ),
        neverlink = neverlink,
        strict_deps = strict_deps,
        java_toolchain = java_toolchain[java_common.JavaToolchainInfo],
    )

def _singlejar(
        ctx,
        inputs,
        output,
        mnemonic = "SingleJar",
        progress_message = "Merge into a single jar.",
        build_target = "",
        check_desugar_deps = False,
        compression = True,
        deploy_manifest_lines = [],
        include_build_data = False,
        include_prefixes = [],
        java_toolchain = None,
        resource_set = None):
    args = ctx.actions.args()
    args.add("--output")
    args.add(output)
    if compression:
        args.add("--compression")
    args.add("--normalize")
    if not include_build_data:
        args.add("--exclude_build_data")
    args.add("--warn_duplicate_resources")
    if inputs:
        args.add("--sources")
        args.add_all(inputs)

    if build_target:
        args.add("--build_target", build_target)
    if check_desugar_deps:
        args.add("--check_desugar_deps")
    if deploy_manifest_lines:
        args.add_all("--deploy_manifest_lines", deploy_manifest_lines)
    if include_prefixes:
        args.add_all("--include_prefixes", include_prefixes)

    args.use_param_file("@%s")
    args.set_param_file_format("multiline")

    ctx.actions.run(
        executable = java_toolchain[java_common.JavaToolchainInfo].single_jar,
        toolchain = "@bazel_tools//tools/jdk:toolchain_type",
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = mnemonic,
        progress_message = progress_message,
        resource_set = resource_set,
    )

def _run(
        ctx,
        host_javabase,
        jvm_flags = [],
        **args):
    """Run a java binary

    Args:
      ctx: The context.
      host_javabase: Target. The host_javabase.
      jvm_flags: Additional arguments to the JVM itself.
      **args: Additional arguments to pass to ctx.actions.run(). Some will get modified.
    """

    if type(ctx) != "ctx":
        fail("Expected type ctx for argument ctx, got %s" % type(ctx))

    if type(host_javabase) != "Target":
        fail("Expected type Target for argument host_javabase, got %s" % type(host_javabase))

    # Set reasonable max heap default. Required to prevent runaway memory usage.
    # Can still be overridden by callers of this method.
    jvm_flags = ["-Xms4G", "-Xmx4G", "-XX:+ExitOnOutOfMemoryError"] + jvm_flags

    # executable should be a File or a FilesToRunProvider
    jar = args.get("executable")
    if type(jar) == "FilesToRunProvider":
        jar = jar.executable
    elif type(jar) != "File":
        fail("Expected type File or FilesToRunProvider for argument executable, got %s" % type(jar))

    java_runtime = host_javabase[java_common.JavaRuntimeInfo]
    args["executable"] = java_runtime.java_executable_exec_path
    args["toolchain"] = "@bazel_tools//tools/jdk:toolchain_type"

    # inputs can be a list or a depset of File
    inputs = args.get("inputs", default = [])
    if type(inputs) == type([]):
        args["inputs"] = depset(direct = inputs + [jar], transitive = [java_runtime.files])
    else:  # inputs is a depset
        args["inputs"] = depset(direct = [jar], transitive = [inputs, java_runtime.files])

    jar_args = ctx.actions.args()
    jar_args.add("-jar", jar)

    args["arguments"] = jvm_flags + [jar_args] + args.get("arguments", default = [])

    ctx.actions.run(**args)

def _create_deploy_jar(
        ctx,
        output = None,
        runtime_jars = depset(),
        java_toolchain = None,
        build_target = "",
        deploy_manifest_lines = []):
    _singlejar(
        ctx,
        inputs = runtime_jars,
        output = output,
        mnemonic = "JavaDeployJar",
        progress_message = "Building deploy jar %s" % output.short_path,
        java_toolchain = java_toolchain,
        build_target = build_target,
        check_desugar_deps = True,
        compression = False,
        deploy_manifest_lines = deploy_manifest_lines,
        resource_set = _resource_set_for_deploy_jar,
    )
    return output

def _resource_set_for_deploy_jar(_os, _inputs_size):
    # parameters are unused but required by the resource_set API
    return {"memory": _SINGLEJAR_MEMORY_FOR_DEPLOY_JAR_MB, "cpu": 1}

java = struct(
    compile = _compile,
    compile_android = _compile_android,
    resolve_package = _resolve_package,
    resolve_package_from_label = _resolve_package_from_label,
    root = _root,
    invalid_java_package = _invalid_java_package,
    run = _run,
    singlejar = _singlejar,
    create_deploy_jar = _create_deploy_jar,
)
