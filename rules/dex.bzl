# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Bazel Dex Commands."""

def _dex(
        ctx,
        input,
        output = None,
        incremental_dexopts = [],
        min_sdk_version = 0,
        dex_exec = None):
    """Dexes a JAR.

    Args:
        ctx: The context.
        input: File. The jar to be dexed.
        output: File. The archive file containing all of the dexes.
        incremental_dexopts: List of strings. Additional command-line flags for the dexing tool when building dexes.
        min_sdk_version: Integer. The minimum targeted sdk version.
        dex_exec: File. The executable dex builder file.
    """
    args = ctx.actions.args()

    args.add("--input_jar", input)
    args.add("--output_zip", output)
    args.add_all(incremental_dexopts)

    if min_sdk_version > 0:
        args.add("--min_sdk_version", min_sdk_version)

    execution_requirements = {}
    if ctx.fragments.android.persistent_android_dex_desugar:
        execution_requirements["supports-workers"] = 1
        if ctx.fragments.android.persistent_multiplex_android_dex_desugar:
            execution_requirements["supports-multiplex-workers"] = 1

    ctx.actions.run(
        executable = dex_exec,
        arguments = [args],
        inputs = [input],
        outputs = [output],
        mnemonic = "DexBuilder",
        progress_message = "Dexing " + input.path + " with applicable dexopts " + str(incremental_dexopts),
        execution_requirements = execution_requirements,
    )

dex = struct(
    dex = _dex,
)
