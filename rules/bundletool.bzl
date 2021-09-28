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

"""Bazel Bundletool Commands."""

load(":java.bzl", _java = "java")

_density_mapping = {
    "ldpi": 120,
    "mdpi": 160,
    "hdpi": 240,
    "xhdpi": 320,
    "xxhdpi": 480,
    "xxxhdpi": 640,
    "tvdpi": 213,
}

def _proto_apk_to_module(
        ctx,
        out = None,
        proto_apk = None,
        zip = None,
        unzip = None):
    # TODO(timpeut): rewrite this as a standalone golang tool
    ctx.actions.run_shell(
        command = """
set -e

IN_DIR=$(mktemp -d)
OUT_DIR=$(mktemp -d)
CUR_PWD=$(pwd)
UNZIP=%s
ZIP=%s
INPUT=%s
OUTPUT=%s

"${UNZIP}" -qq "${INPUT}" -d "${IN_DIR}"
cd "${IN_DIR}"

if [ -f resources.pb ]; then
  mv resources.pb "${OUT_DIR}/"
fi

if [ -f AndroidManifest.xml ]; then
  mkdir "${OUT_DIR}/manifest"
  mv AndroidManifest.xml "${OUT_DIR}/manifest/"
fi

NUM_DEX=`ls -1 *.dex 2>/dev/null | wc -l`
if [ $NUM_DEX != 0 ]; then
  mkdir "${OUT_DIR}/dex"
  mv *.dex "${OUT_DIR}/dex/"
fi

if [ -d res ]; then
  mv res "${OUT_DIR}/res"
fi

if [ -d assets ]; then
  mv assets "${OUT_DIR}/"
fi

if [ -d lib ]; then
  mv lib "${OUT_DIR}/"
fi

UNKNOWN=`ls -1 * 2>/dev/null | wc -l`
if [ $UNKNOWN != 0 ]; then
  mkdir "${OUT_DIR}/root"
  mv * "${OUT_DIR}/root/"
fi

cd "${OUT_DIR}"
"${CUR_PWD}/${ZIP}" "${CUR_PWD}/${OUTPUT}" -Drq0 .
""" % (
            unzip.executable.path,
            zip.executable.path,
            proto_apk.path,
            out.path,
        ),
        tools = [zip, unzip],
        arguments = [],
        inputs = [proto_apk],
        outputs = [out],
        mnemonic = "Rebundle",
        progress_message = "Rebundle to %s" % out.short_path,
    )

def _build(
        ctx,
        out = None,
        modules = [],
        config = None,
        metadata = dict(),
        bundletool = None,
        host_javabase = None):
    args = ctx.actions.args()
    args.add("build-bundle")
    args.add("--output", out)
    if modules:
        args.add_joined("--modules", modules, join_with = ",")
    if config:
        args.add("--config", config)
    for path, f in metadata.items():
        args.add("--metadata-file", "%s:%s" % (path, f.path))

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = bundletool,
        arguments = [args],
        inputs = (
            modules +
            ([config] if config else []) +
            metadata.values()
        ),
        outputs = [out],
        mnemonic = "BuildBundle",
        progress_message = "Building bundle %s" % out.short_path,
    )

def _extract_config(
        ctx,
        out = None,
        aab = None,
        bundletool = None,
        host_javabase = None):
    # Need to execute as a shell script as the tool outputs to stdout
    cmd = """
set -e
contents=`%s -jar %s dump config --bundle %s`
echo "$contents" > %s
""" % (
        host_javabase[java_common.JavaRuntimeInfo].java_executable_exec_path,
        bundletool.executable.path,
        aab.path,
        out.path,
    )

    ctx.actions.run_shell(
        inputs = [aab],
        outputs = [out],
        tools = depset([bundletool.executable], transitive = [host_javabase[java_common.JavaRuntimeInfo].files]),
        mnemonic = "ExtractBundleConfig",
        progress_message = "Extract bundle config to %s" % out.short_path,
        command = cmd,
    )

def _extract_manifest(
        ctx,
        out = None,
        aab = None,
        module = None,
        xpath = None,
        bundletool = None,
        host_javabase = None):
    # Need to execute as a shell script as the tool outputs to stdout
    extra_flags = []
    if module:
        extra_flags.append("--module " + module)
    if xpath:
        extra_flags.append("--xpath " + xpath)
    cmd = """
set -e
contents=`%s -jar %s dump manifest --bundle %s %s`
echo "$contents" > %s
""" % (
        host_javabase[java_common.JavaRuntimeInfo].java_executable_exec_path,
        bundletool.executable.path,
        aab.path,
        " ".join(extra_flags),
        out.path,
    )

    ctx.actions.run_shell(
        inputs = [aab],
        outputs = [out],
        tools = depset([bundletool.executable], transitive = [host_javabase[java_common.JavaRuntimeInfo].files]),
        mnemonic = "ExtractBundleManifest",
        progress_message = "Extract bundle manifest to %s" % out.short_path,
        command = cmd,
    )

def _bundle_to_apks(
        ctx,
        out = None,
        bundle = None,
        universal = False,
        device_spec = None,
        keystore = None,
        modules = None,
        aapt2 = None,
        bundletool = None,
        host_javabase = None):
    inputs = [bundle]
    args = ctx.actions.args()
    args.add("build-apks")
    args.add("--output", out)
    args.add("--bundle", bundle)
    args.add("--aapt2", aapt2.executable.path)

    if universal:
        args.add("--mode=universal")

    if keystore:
        args.add("--ks", keystore.path)
        args.add("--ks-pass", "pass:android")
        args.add("--ks-key-alias", "AndroidDebugKey")
        inputs.append(keystore)

    if device_spec:
        args.add("--device-spec", device_spec)
        inputs.append(device_spec)

    if modules:
        args.add_joined("--modules", modules, join_with = ",")

    _java.run(
        ctx = ctx,
        host_javabase = host_javabase,
        executable = bundletool,
        arguments = [args],
        inputs = inputs,
        outputs = [out],
        tools = [aapt2],
        mnemonic = "BundleToApks",
        progress_message = "Converting bundle to .apks: %s" % out.short_path,
    )

def _build_device_json(
        ctx,
        out,
        abis,
        locales,
        density,
        sdk_version):
    json_content = json.encode(struct(
        supportedAbis = abis,
        supportedLocales = locales,
        screenDensity = _density_mapping[density],
        sdkVersion = int(sdk_version),
    ))
    ctx.actions.write(out, json_content)

bundletool = struct(
    build = _build,
    build_device_json = _build_device_json,
    bundle_to_apks = _bundle_to_apks,
    extract_config = _extract_config,
    extract_manifest = _extract_manifest,
    proto_apk_to_module = _proto_apk_to_module,
)
