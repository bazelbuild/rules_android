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

"""Bazel common library for the Android rules."""

load(":utils.bzl", "get_android_toolchain", _log = "log")
load("//rules/android_common:reexport_android_common.bzl", _native_android_common = "native_android_common")

# Suffix attached to the Starlark portion of android_binary target
_PACKAGED_RESOURCES_SUFFIX = "_RESOURCES_DO_NOT_USE"

# Validates that the packages listed under "deps" all have the given constraint. If a package
# does not have this attribute, an error is generated.
def _validate_constraints(targets, constraint):
    for target in targets:
        if JavaInfo in target:
            if constraint not in java_common.get_constraints(target[JavaInfo]):
                _log.error("%s: does not have constraint '%s'" % (target.label, constraint))

TARGET_DNE = "Target '%s' does not exist or is a file and is not allowed."

def _check_rule(targets):
    _validate_constraints(targets, "android")

def _get_java_toolchain(ctx):
    if not hasattr(ctx.attr, "_java_toolchain"):
        _log.error("Missing _java_toolchain attr")
    return ctx.attr._java_toolchain

def _get_host_javabase(ctx):
    if not hasattr(ctx.attr, "_host_javabase"):
        _log.error("Missing _host_javabase attr")
    return ctx.attr._host_javabase

def _filter_zip_include(ctx, in_zip, out_zip, filters = []):
    """Creates a copy of a zip file with files that match filters."""
    args = ctx.actions.args()
    args.add("-q")
    args.add(in_zip.path)
    args.add_all(filters)
    args.add("--copy")
    args.add("--out")
    args.add(out_zip.path)
    ctx.actions.run(
        executable = get_android_toolchain(ctx).zip_tool.files_to_run,
        arguments = [args],
        inputs = [in_zip],
        outputs = [out_zip],
        mnemonic = "FilterZipInclude",
        progress_message = "Filtering %s" % in_zip.short_path,
    )

def _filter_zip_exclude(
        ctx,
        output = None,
        input = None,
        filter_zips = [],
        filter_types = [],
        filters = [],
        check_hash_mismatch = False,
        compression_mode = "DONT_CARE"):
    """Filter out entries from a zip file based on the filter types and filter zips.

    Args:
        ctx: The Context.
        output: File. The output zip.
        input: File. The input zip.
        filter_zips: List of Files. The zips used as filters. Contents in these files will be omitted from the output zip.
        filter_types: List of strings. Only contents in the filter Zip files with these extensions will be filtered out.
        filters: List of strings. The regex to the set of filters to always check for and remove.
        check_hash_mismatch: Boolean. Whether to enable checking of hash mismatches for files with the same name.
        compression_mode: String. The compression mode for the output zip. There are 3 modes:
            * FORCE_DEFLATE: Force the output zip to be compressed.
            * FORCE_STORED: Force the output zip to be stored.
            * DONT_CARE: The output zip will have the same compression mode with the input zip.
    """
    args = ctx.actions.args()

    args.add("--inputZip", input.path)
    args.add("--outputZip", output.path)

    if filter_zips:
        args.add("--filterZips", ",".join([z.path for z in filter_zips]))
    if filter_types:
        args.add("--filterTypes", ",".join(filter_types))
    if filters:
        args.add("--explicitFilters", ",".join(filters))

    if check_hash_mismatch:
        args.add("--checkHashMismatch", "ERROR")
    else:
        args.add("--checkHashMismatch", "IGNORE")

    args.add("--outputMode", compression_mode)

    ctx.actions.run(
        executable = get_android_toolchain(ctx).zip_filter.files_to_run,
        arguments = [args],
        inputs = [input] + filter_zips,
        outputs = [output],
        mnemonic = "FilterZipExclude",
        progress_message = "Filtering %s" % input.short_path,
    )

def _create_signer_properties(ctx, oldest_key):
    properties = ctx.actions.declare_file("%s/keystore.properties" % ctx.label.name)
    ctx.actions.expand_template(
        template = ctx.file._bundle_keystore_properties,
        output = properties,
        substitutions = {"%oldest_key%": oldest_key.short_path},
    )
    return properties

common = struct(
    PACKAGED_RESOURCES_SUFFIX = _PACKAGED_RESOURCES_SUFFIX,
    check_rule = _check_rule,
    create_signer_properties = _create_signer_properties,
    get_host_javabase = _get_host_javabase,
    get_java_toolchain = _get_java_toolchain,
    filter_zip_include = _filter_zip_include,
    filter_zip_exclude = _filter_zip_exclude,
)

android_common = _native_android_common
