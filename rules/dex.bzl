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

load("@bazel_skylib//lib:collections.bzl", "collections")
load("//rules:attrs.bzl", _attrs = "attrs")

_tristate = _attrs.tristate

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

def _get_dx_artifact(ctx, basename):
    return ctx.actions.declare_file("_dx_migrated/" + ctx.label.name + "/" + basename)

def _get_effective_incremental_dexing(
        force_incremental_dexing = _tristate.auto,
        has_forbidden_dexopts = False,
        incremental_dexing_after_proguard_by_default = True,
        incremental_dexing_shards_after_proguard = True,
        is_binary_optimized = False,
        use_incremental_dexing = True):
    if (is_binary_optimized and
        force_incremental_dexing == _tristate.yes and incremental_dexing_shards_after_proguard <= 0):
        fail("Target cannot be incrementally dexed because it uses Proguard")

    if force_incremental_dexing == _tristate.yes:
        return True

    if force_incremental_dexing == _tristate.no:
        return False

    # If there are incompatible dexopts and the incremental_dexing attr is not set, we silently don't run
    # incremental dexing.
    if has_forbidden_dexopts or (is_binary_optimized and not incremental_dexing_after_proguard_by_default):
        return False

    # use_incremental_dexing config flag will take effect if incremental_dexing attr is not set
    return use_incremental_dexing

def _dex_merge(
        ctx,
        output = None,
        inputs = [],
        multidex_strategy = "minimal",
        main_dex_list = None,
        dexopts = [],
        dexmerger = None):
    args = ctx.actions.args()
    args.add("--multidex", multidex_strategy)
    args.add_all(inputs, before_each = "--input")
    args.add("--output", output)
    args.add_all(_merger_dexopts(ctx, dexopts))

    if main_dex_list:
        inputs.append(main_dex_list)
        args.add("-main_dex_list", main_dex_list)

    ctx.actions.run(
        executable = dexmerger,
        arguments = [args],
        inputs = inputs,
        outputs = [output],
        mnemonic = "DexMerger",
        progress_message = "Assembling dex files into" + output.short_path,
    )

def _merger_dexopts(tokenized_dexopts, dexopts_supported_in_dex_merger):
    return _normalize_dexopts(_filter_dexopts(tokenized_dexopts, dexopts_supported_in_dex_merger))

def _incremental_dexopts(tokenized_dexopts, dexopts_supported_in_incremental_dexing):
    return _normalize_dexopts(_filter_dexopts(tokenized_dexopts, dexopts_supported_in_incremental_dexing))

def _filter_dexopts(candidates, allowed):
    return [c for c in candidates if c in allowed]

def _normalize_dexopts(tokenized_dexopts):
    def _dx_to_dexbuilder(opt):
        return opt.replace("--no-", "--no")

    return collections.uniq(sorted([_dx_to_dexbuilder(token) for token in tokenized_dexopts]))

dex = struct(
    dex = _dex,
    dex_merge = _dex_merge,
    get_dx_artifact = _get_dx_artifact,
    get_effective_incremental_dexing = _get_effective_incremental_dexing,
    incremental_dexopts = _incremental_dexopts,
    normalize_dexopts = _normalize_dexopts,
)
