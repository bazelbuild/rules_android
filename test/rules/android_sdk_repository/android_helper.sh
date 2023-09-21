#!/bin/bash
#
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

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -uo pipefail; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v2 ---

source "$(rlocation rules_android/test/bashunit/unittest.bash)" || \
  (echo >&2 "Failed to locate bashunit.sh" && exit 1)

function set_up() {
  # Clean out the repository.
  rm -rf *
  touch WORKSPACE

  # Clean out the test android SDK if any
  rm -rf "${TEST_TMPDIR}/android_sdk"

  # Make sure the rules exist and seed the WORKSPACE.
  rm -rf "${TEST_TMPDIR}/android_sdk_repository_src"
  set_up_rules
}

function set_up_rules() {
  local android_revision_rule="$(rlocation rules_android/rules/android_revision.bzl)"

  local repo_rule="$(rlocation rules_android/rules/android_sdk_repository/rule.bzl)"
  local repo_rule_dir="$(dirname "${repo_rule}")"
  local dest_dir="${TEST_TMPDIR}/android_sdk_repository_src"
  mkdir -p "${dest_dir}/rules/android_sdk_repository"
  cp -r "${repo_rule_dir}"/* "${dest_dir}/rules/android_sdk_repository"
  cat > "${dest_dir}/WORKSPACE" <<EOF
workspace(name = "android_sdk_repository_src")
EOF
  cat > "${dest_dir}/rules/BUILD" <<EOF
exports_files(["*.bzl"])
EOF
  cp "${android_revision_rule}" "${dest_dir}/rules/"
  cat > "${dest_dir}/rules/android_sdk_repository/BUILD" <<EOF
exports_files(["*.bzl"])
EOF

  cat >> WORKSPACE <<EOF
local_repository(
    name = "android_sdk_repository_src",
    path = "${dest_dir}",
)
load("@android_sdk_repository_src//rules/android_sdk_repository:rule.bzl", "android_sdk_repository")
EOF
}

function create_android_sdk() {
  # Create a fake Android SDK that will be available for the repository rule.
  local location="${TEST_TMPDIR}/android_sdk"
  mkdir -p "${location}"

  mkdir "${location}/platform-tools"
  touch "${location}/platform-tools/adb"

  echo "${location}"
}

function add_platforms() {
  local sdk_path="${1}"
  shift

  # Add all requested API levels
  for level in "$@"; do
    local dir="${sdk_path}/platforms/android-${level}"
    mkdir -p "${dir}"
    touch "${dir}/android.jar"
    touch "${dir}/framework.aidl"

    local system_image_dir="${sdk_path}/system-images/android-${level}"
    mkdir -p "${system_image_dir}/default/arm64-v8a"
    mkdir -p "${system_image_dir}/default/x86_64"
  done
}

function add_build_tools() {
  local sdk_path="${1}"
  shift

  # Add all requested tools
  for version in "$@"; do
    local dir="${sdk_path}/build-tools/${version}"
    mkdir -p "${dir}/lib"
    touch "${dir}/aapt"
    touch "${dir}/aidl"
    touch "${dir}/lib/apksigner.jar"
    touch "${dir}/lib/d8.jar"
    touch "${dir}/lib/dx.jar"
    touch "${dir}/mainDexClasses.rules"
    touch "${dir}/zipalign"
  done
}

function create_android_sdk_basic() {
  local sdk_path="$(create_android_sdk)"
  add_platforms "${sdk_path}" 31
  add_build_tools "${sdk_path}" 30.0.3
  echo "${sdk_path}"
}

function create_verify() {
  mkdir verify
  cat > verify/BUILD <<EOF
genrule(
    name = "check_sdk",
    outs = ["check_sdk.log"],
    cmd = select({
        "@androidsdk//:has_androidsdk": "echo sdk present > \$@",
        "//conditions:default": "echo sdk missing > \$@",
    }),
)
EOF

  "${BIT_BAZEL_BINARY}" build //verify:check_sdk >& $TEST_log || fail "Expected success"
  cat bazel-bin/verify/check_sdk.log >$TEST_log
}

function verify_no_android_sdk() {
  create_verify
  expect_log "sdk missing"
}

function verify_android_sdk() {
  create_verify
  expect_log "sdk present"
  "${BIT_BAZEL_BINARY}" query @androidsdk//:files >& $TEST_log || fail "Expected to exist"
}

function write_platforms() {
  mkdir -p platforms
  cat > platforms/BUILD <<EOF
platform(
    name = "arm64-v8a",
    constraint_values = [
        "@platforms//os:android",
        "@platforms//cpu:arm64",
    ],
)
EOF
}

function write_android_sdk_provider() {
  mkdir -p sdk_check
  cat > sdk_check/check.bzl <<EOF
def _find_api_level(android_jar):
    # expected format: external/androidsdk/platforms/android-LEVEL/android.jar
    if not android_jar.startswith("external/androidsdk/platforms/android-"):
        return "unknown"
    if not android_jar.endswith("/android.jar"):
        return "unknown"
    level = android_jar.removeprefix("external/androidsdk/platforms/android-")
    level = level.removesuffix("/android.jar")
    return level
def _show_sdk_info_impl(ctx):
    print("SDK check results:")
    provider = ctx.attr._android_sdk[AndroidSdkInfo]
    print("build_tools_version: %s" % provider.build_tools_version)
    print("api_level: %s" % _find_api_level(provider.android_jar.path))
show_sdk_info = rule(
    implementation = _show_sdk_info_impl,
    attrs = {
        "_android_sdk": attr.label(default = "@androidsdk//:sdk"),
    },
)
EOF
}

function write_android_sdk_provider_platforms() {
  mkdir -p sdk_check
  cat > sdk_check/check.bzl <<EOF
def _find_api_level(android_jar):
    # expected format: external/androidsdk/platforms/android-LEVEL/android.jar
    if not android_jar.startswith("external/androidsdk/platforms/android-"):
        return "unknown"
    if not android_jar.endswith("/android.jar"):
        return "unknown"
    level = android_jar.removeprefix("external/androidsdk/platforms/android-")
    level = level.removesuffix("/android.jar")
    return level
def _show_sdk_info_impl(ctx):
    print("SDK check results:")
    toolchain = ctx.toolchains["@bazel_tools//tools/android:sdk_toolchain_type"]
    if not toolchain:
        print("No SDK found via toolchain")
        return
    provider = toolchain.android_sdk_info
    print("build_tools_version: %s" % provider.build_tools_version)
    print("api_level: %s" % _find_api_level(provider.android_jar.path))
show_sdk_info = rule(
    implementation = _show_sdk_info_impl,
    toolchains = [
        config_common.toolchain_type(
            "@bazel_tools//tools/android:sdk_toolchain_type",
            mandatory = False,
        ),
    ],
)
EOF
}

function check_android_sdk_provider() {
  local extra_args=(
    # macOS bash doesn't deal well with empty arrays, so make sure this has
    # contents.
    "--experimental_google_legacy_api"
    "$@"
  )

  if [[ ${ENABLE_PLATFORMS:-false} == "true" ]]; then
    write_platforms
    write_android_sdk_provider_platforms
    extra_args+=(
      "--incompatible_enable_android_toolchain_resolution"
      "--platforms=//platforms:arm64-v8a"
    )
  else
    write_android_sdk_provider
  fi

  cat > sdk_check/BUILD <<EOF
load(":check.bzl", "show_sdk_info")
show_sdk_info(
    name = "check",
)
EOF

  "${BIT_BAZEL_BINARY}" \
    build \
    "${extra_args[@]}" \
    -- \
    //sdk_check:check >& $TEST_log || fail "Expected success"
  expect_log "SDK check results"
}
