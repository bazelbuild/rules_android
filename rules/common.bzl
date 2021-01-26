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

load(":java.bzl", _java = "java")
load(":utils.bzl", "get_android_sdk", "get_android_toolchain", _log = "log")

# TODO(ostonge): Remove once kotlin/jvm_library.internal.bzl
# is updated and released to use the java.resolve_package function
def _java_package(label, custom_package):
    return _java.resolve_package_from_label(label, custom_package)

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

def _sign_apk(ctx, unsigned_apk, signed_apk, keystore = None, signing_keys = [], signing_lineage = None):
    """Signs an apk. Usage of keystore is deprecated. Prefer using signing_keys."""
    inputs = [unsigned_apk]
    signer_args = ctx.actions.args()
    signer_args.add("sign")

    if signing_keys:
        inputs.extend(signing_keys)
        for i, key in enumerate(signing_keys):
            if i > 0:
                signer_args.add("--next-signer")
            signer_args.add("--ks")
            signer_args.add(key.path)
            signer_args.add("--ks-pass")
            signer_args.add("pass:android")
        if signing_lineage:
            inputs.append(signing_lineage)
            signer_args.add("--lineage", signing_lineage.path)
    elif keystore:
        inputs.append(keystore)
        signer_args.add("--ks", keystore.path)
        signer_args.add("--ks-pass", "pass:android")

    signer_args.add("--v1-signing-enabled", ctx.fragments.android.apk_signing_method_v1)
    signer_args.add("--v1-signer-name", "CERT")
    signer_args.add("--v2-signing-enabled", ctx.fragments.android.apk_signing_method_v2)
    signer_args.add("--out", signed_apk.path)
    signer_args.add(unsigned_apk.path)
    ctx.actions.run(
        executable = get_android_sdk(ctx).apk_signer,
        inputs = inputs,
        outputs = [signed_apk],
        arguments = [signer_args],
        mnemonic = "ApkSignerTool",
        progress_message = "Signing APK for %s" % unsigned_apk.path,
    )
    return signed_apk

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

common = struct(
    check_rule = _check_rule,
    get_host_javabase = _get_host_javabase,
    get_java_toolchain = _get_java_toolchain,
    filter_zip = _filter_zip,
    java_package = _java_package,
    sign_apk = _sign_apk,
)
