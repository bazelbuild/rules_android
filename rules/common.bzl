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

def _filter_zip(ctx, in_zip, out_zip, filters = []):
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
        mnemonic = "FilterZip",
        progress_message = "Filtering %s" % in_zip.short_path,
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
    check_rule = _check_rule,
    create_signer_properties = _create_signer_properties,
    get_host_javabase = _get_host_javabase,
    get_java_toolchain = _get_java_toolchain,
    filter_zip = _filter_zip,
)
