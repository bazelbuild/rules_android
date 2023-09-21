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

def _desugar(
        ctx,
        input,
        output = None,
        classpath = None,
        bootclasspath = [],
        min_sdk_version = 0,
        library_desugaring = True,
        desugar_exec = None,
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
    """

    args = ctx.actions.args()
    args.use_param_file("@%s", use_always = True)  # Required for workers.
    args.set_param_file_format("multiline")
    args.add("--input", input)
    args.add("--output", output)
    args.add_all(classpath, before_each = "--classpath_entry")
    args.add_all(bootclasspath, before_each = "--bootclasspath_entry")

    if library_desugaring:
        if ctx.fragments.android.check_desugar_deps:
            args.add("--emit_dependency_metadata_as_needed")

        if ctx.fragments.android.desugar_java8_libs and library_desugaring:
            args.add("--desugar_supported_core_libs")

    if min_sdk_version > 0:
        args.add("--min_sdk_version", str(min_sdk_version))

    ctx.actions.run(
        inputs = depset([input] + bootclasspath, transitive = [classpath]),
        outputs = [output],
        executable = desugar_exec,
        arguments = [args],
        mnemonic = "Desugar",
        progress_message = "Desugaring " + input.short_path + " for Android",
        execution_requirements = {"supports-workers": "1"},
        toolchain = toolchain_type,
    )

desugar = struct(
    desugar = _desugar,
)
