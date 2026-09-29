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
"""Bazel Desugar Commands."""

load("//rules:utils.bzl", "get_android_sdk")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//rules/flags:flags.bzl", "read_possibly_native_flag")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

visibility(PROJECT_VISIBILITY)

def _desugar(
        ctx,
        input,
        output = None,
        classpath = None,
        bootclasspath = [],
        min_sdk_version = 0,
        library_desugaring = True,
        desugar_exec = None,
        desugared_lib_config = None,
        toolchain_type = None):
    """Desugars a JAR.

    Args:
        ctx: The context.
        input: File. The jar to be desugared.
        output: File. The desugared jar.
        classpath: Depset of Files. The transitive classpath needed to resolve symbols in the input jar.
        bootclasspath: List of Files. Bootclasspaths that was used to compile the input jar with.
        min_sdk_version: Integer. The minimum targeted sdk version.
        library_desugaring: Boolean. Whether to enable core library desugaring.
        desugar_exec: File. The executable desugar file.
        desugared_lib_config: File. The json file containing desugarer options.
        toolchain_type: Label or String. The toolchain to use for running the desugar action.
    """

    args = ctx.actions.args()
    args.use_param_file("@%s", use_always = True)  # Required for workers.
    args.set_param_file_format("multiline")

    args.add("--input", input)
    args.add("--output", output)
    args.add_all(classpath, before_each = "--classpath_entry")
    args.add_all(bootclasspath, before_each = "--bootclasspath_entry")

    input_file_deps = [input]
    if library_desugaring:
        args.add("--emit_dependency_metadata_as_needed")
        if read_possibly_native_flag(ctx, "desugar_java8_libs"):
            args.add("--desugar_supported_core_libs")

    # Unconditionally add --desugared_lib_config. This matches the behavior of tools/android/d8_desugar.sh.
    args.add("--desugared_lib_config", desugared_lib_config)
    if desugared_lib_config:
        input_file_deps.append(desugared_lib_config)
    else:
        fail("Got NoneType for desugared_lib_config")

    if min_sdk_version > 0:
        args.add("--min_sdk_version", str(min_sdk_version))

    ctx.actions.run(
        inputs = depset(input_file_deps + bootclasspath, transitive = [classpath]),
        outputs = [output],
        executable = desugar_exec,
        arguments = [args],
        mnemonic = "Desugar",
        progress_message = "Desugaring %{input} for Android",
        execution_requirements = {"supports-workers": "1", "supports-path-mapping": "1"},
        use_default_shell_env = True,
        toolchain = toolchain_type,
    )

def _get_boot_classpath(target, ctx):
    """Returns the bootclasspath to use when desugaring the target.

    Prefers the bootclasspath the target was compiled against, falling back to
    the android.jar from the Android SDK toolchain. The calling rule or aspect
    must request the Android SDK toolchain.

    Args:
      target: The target.
      ctx: The context.

    Returns:
      A list of Files.
    """
    if JavaInfo in target:
        compilation_info = target[JavaInfo].compilation_info
        if compilation_info and compilation_info.boot_classpath:
            return compilation_info.boot_classpath

    android_jar = get_android_sdk(ctx).android_jar
    if android_jar:
        return [android_jar]

    # This shouldn't ever be reached, but if it is, we should be clear about the error.
    fail("No compilation info or android jar!")

desugar = struct(
    desugar = _desugar,
    get_boot_classpath = _get_boot_classpath,
)
