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
"""Creates the apk(s)."""

load("//rules:utils.bzl", "get_android_sdk")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":utils.bzl", "utils")

visibility(PROJECT_VISIBILITY)

def _compile_android_manifest(ctx, manifest, resources_zip, out_manifest):
    """Compile AndroidManifest.xml."""
    android_jar = get_android_sdk(ctx).android_jar
    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "-flagfile=%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add("-aapt2", ctx.executable._aapt2)
    args.add("-manifest", manifest)
    args.add("-out", out_manifest)
    args.add("-sdk_jar", android_jar)
    args.add("-res", resources_zip)
    args.add("-force_debuggable=true")

    ctx.actions.run(
        executable = ctx.executable._android_kit,
        arguments = ["manifest", args],
        tools = [ctx.executable._aapt2],
        inputs = [manifest, resources_zip, android_jar],
        outputs = [out_manifest],
        mnemonic = "CompileAndroidManifest",
        progress_message = "MI Compiling AndroidManifest.xml from " + manifest.path,
    )

def _patch_split_manifests(ctx, orig_manifest, split_manifests, out_manifest_package_name):
    args = ctx.actions.args()
    args.add("-in", orig_manifest)
    args.add("-split", ",".join(["%s:%s" % (k, v.path) for k, v in split_manifests.items()]))

    # prefer setting hasCode to always false. Otherwise dex2oat runs on installation
    args.add("-attr", "application:hasCode:false")
    args.add("-pkg", out_manifest_package_name)

    ctx.actions.run(
        executable = ctx.executable._android_kit,
        arguments = ["patch", args],
        inputs = [orig_manifest],
        outputs = [out_manifest_package_name] + split_manifests.values(),
        mnemonic = "PatchAndroidManifest",
        progress_message = "MI Patch split manifests",
    )

def _make_split_apk(ctx, dirs, artifacts, debug_signing_keys, debug_signing_lineage_file, key_rotation_min_sdk, keystore_signing_password, out):
    unsigned = utils.isolated_declare_file(ctx, out.basename + "_unsigned", sibling = out)

    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "--flagfile=%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add("-out", unsigned)
    args.add_joined("-in", artifacts, join_with = ",")

    inputs = artifacts

    dir_paths = {}
    for d in dirs:
        inputs.append(d)
        dir_paths[d.dirname] = True

    args.add_joined("-dir", dir_paths.keys(), join_with = ",")

    ctx.actions.run(
        executable = ctx.executable._android_kit,
        arguments = ["repack", args],
        inputs = inputs,
        outputs = [unsigned],
        mnemonic = "MakeSplitApk",
        progress_message = "MI Making split app %s" % out.path,
    )

    _zipalign_sign(ctx, unsigned, out, debug_signing_keys, debug_signing_lineage_file, key_rotation_min_sdk, keystore_signing_password)

def make_split_apks(
        ctx,
        manifest,
        r_dex,
        dexes,
        resource_apk,
        jar_resources,
        native_zips,
        swigdeps_file,
        debug_signing_keys,
        debug_signing_lineage_file,
        key_rotation_min_sdk,
        keystore_signing_password,
        sibling):
    """Create a split for each dex and for resources"""
    manifest_package_name = utils.isolated_declare_file(ctx, "manifest_package_name.txt", sibling = sibling)
    manifests = {}
    artifacts = {}
    dirs = {}
    splits = []
    to_pack = dexes + [r_dex]
    if native_zips:
        to_pack.extend(native_zips)
    for i, artifact in enumerate(to_pack):
        # the split attr in the manifest will be used to name the file on the device like
        # split_${SPLIT_ID}.apk. We need to follow the same pattern so that we can compare
        # files during sync time and only do the incremental install.
        # The split names need to be valid java package names
        name = "mi_" + artifact.basename.split(".")[0].replace("-", "_")
        manifests[name] = utils.isolated_declare_file(
            ctx,
            "split_manifests/AndroidManifest_%s.xml" % name,
            sibling = sibling,
        )
        artifacts[name] = [artifact]

    # If we have a swigdeps file push it in the jar resources zip to avoid creating an extra one.
    if jar_resources or swigdeps_file:
        name = "jresources"
        manifests[name] = utils.isolated_declare_file(
            ctx,
            "split_manifests/AndroidManifest_%s.xml" % name,
            sibling = sibling,
        )

        if jar_resources:
            artifacts[name] = jar_resources

        if swigdeps_file:
            dirs[name] = [swigdeps_file]

    _patch_split_manifests(ctx, manifest, manifests, manifest_package_name)
    for k, v in manifests.items():
        compiled = utils.isolated_declare_file(
            ctx,
            "split_manifests/%s/AndroidManifest.xml" % k,
            sibling = sibling,
        )
        _compile_android_manifest(ctx, v, resource_apk, compiled)
        split = utils.isolated_declare_file(
            ctx,
            "splits/split_%s.apk" % k,
            sibling = sibling,
        )
        _make_split_apk(
            ctx,
            [compiled] + dirs.get(k, []),
            artifacts.get(k, []),
            debug_signing_keys,
            debug_signing_lineage_file,
            key_rotation_min_sdk,
            keystore_signing_password,
            split,
        )
        splits.append(split)

    # make the base split
    compiled = utils.isolated_declare_file(ctx, "split_manifests/base/AndroidManifest.xml", sibling = sibling)
    _compile_android_manifest(ctx, manifest, resource_apk, compiled)

    # base needs to have code and declare it. Otherwise classpath will be empty :(
    # Use legacy dex here
    java8_legacy = utils.isolated_declare_file(ctx, ctx.label.name + "_mi/dex_java8_legacy/java8_legacy.zip")
    ctx.actions.run_shell(
        command = "cp $1 $2",
        arguments = [
            ctx.file._mi_java8_legacy_dex.path,
            java8_legacy.path,
        ],
        inputs = [ctx.file._mi_java8_legacy_dex],
        outputs = [java8_legacy],
        mnemonic = "CopyJava8Legacy",
        progress_message = "MI Copy %s to %s" % (ctx.file._mi_java8_legacy_dex.path, java8_legacy.path),
    )

    # Resources are now in the base apk to support RRO. Previously they were a separate split, but
    # base reinstalls no longer require a full reinstall.
    base = utils.isolated_declare_file(ctx, "splits/base.apk", sibling = sibling)
    _make_split_apk(ctx, [compiled], [resource_apk, java8_legacy], debug_signing_keys, debug_signing_lineage_file, key_rotation_min_sdk, keystore_signing_password, base)
    splits.append(base)

    return manifest_package_name, splits

def _zipalign_sign(ctx, unsigned_apk, signed_apk, debug_signing_keys, debug_signing_lineage_file, key_rotation_min_sdk, keystore_signing_password):
    """Zipalign and signs the given apk."""

    signing_params = ((("--lineage %s " % debug_signing_lineage_file.path) if debug_signing_lineage_file else "") +
                      (("--rotation-min-sdk-version %s " % key_rotation_min_sdk) if key_rotation_min_sdk else "") +
                      " --next-signer ".join([
                          "--ks %s --ks-pass pass:%s" % (debug_signing_key.path, keystore_signing_password)
                          for debug_signing_key in debug_signing_keys
                      ]) +
                      " --v1-signing-enabled true" +
                      " --v1-signer-name CERT" +
                      " --v2-signing-enabled true" +
                      " --v3-signing-enabled true" +
                      " --deterministic-dsa-signing true" +
                      " --provider-class org.bouncycastle.jce.provider.BouncyCastleProvider")

    # note zipalign usage:
    # https://cs.android.com/android/platform/superproject/main/+/main:build/make/tools/zipalign/ZipAlignMain.cpp

    cmd = """
zipalign=$1
unsigned_apk=$2
jvm=$3
apk_signer=$4
signing_params=$5
signed_apk=$6
tmp_dir=$(mktemp -d)
tmp_apk="${tmp_dir}/zipaligned.apk"
${zipalign} -P 16 4 ${unsigned_apk} ${tmp_apk}
${jvm} -jar ${apk_signer} sign ${signing_params} --out ${signed_apk} ${tmp_apk}
"""
    ctx.actions.run_shell(
        command = cmd,
        arguments = [
            ctx.executable._zipalign.path,
            unsigned_apk.path,
            utils.host_jvm_path(ctx),
            utils.first(ctx.attr._apk_signer[DefaultInfo].files.to_list()).path,
            signing_params,
            signed_apk.path,
        ],
        tools = [ctx.executable._zipalign],
        inputs = (debug_signing_keys +
                  ([debug_signing_lineage_file] if debug_signing_lineage_file else []) +
                  [unsigned_apk] +
                  ctx.attr._apk_signer[DefaultInfo].files.to_list() +
                  ctx.attr._java_jdk[DefaultInfo].files.to_list()),
        outputs = [signed_apk],
        mnemonic = "SignShellApp",
        progress_message = "MI Signing shell app %s" % unsigned_apk.path,
    )
