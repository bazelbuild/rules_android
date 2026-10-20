#!/bin/bash
# Copyright 2026 The Bazel Authors. All rights reserved.
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
  local module_file
  module_file="$(rlocation rules_android/MODULE.bazel)"
  local rules_dir
  rules_dir="$(dirname "$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "${module_file}")")"
  local sdk_path="${PWD}/sdk"
  mkdir -p sdk/platforms/android-35 sdk/build-tools/35.0.0/lib sdk/platform-tools
  touch sdk/platforms/android-35/{android.jar,framework.aidl}
  touch sdk/build-tools/35.0.0/{aapt,aapt2,aidl,zipalign,mainDexClasses.rules}
  touch sdk/build-tools/35.0.0/lib/{apksigner.jar,d8.jar,dx.jar}
  touch sdk/platform-tools/adb

  cat > MODULE.bazel <<EOF
module(name = "desugar_worker_test")
bazel_dep(name = "rules_android", version = "0.8.0")
local_path_override(module_name = "rules_android", path = "${rules_dir}")

android_sdk = use_extension("@rules_android//rules/android_sdk_repository:rule.bzl", "android_sdk_repository_extension")
android_sdk.configure(path = "${sdk_path}")
use_repo(android_sdk, "androidsdk")
register_toolchains("@androidsdk//:all")

android_tools = use_extension("@rules_android//bzlmod_extensions:android_extensions.bzl", "remote_android_tools_extensions")
use_repo(android_tools, "android_tools")
EOF

  cat >> MODULE.bazel <<'EOF'
flag_alias(
    name = "internal_persistent_android_dex_desugar",
    starlark_flag = "@rules_android//flags:internal_persistent_android_dex_desugar",
)
flag_alias(
    name = "internal_persistent_multiplex_android_dex_desugar",
    starlark_flag = "@rules_android//flags:internal_persistent_multiplex_android_dex_desugar",
)
EOF

  cat > .bazelrc <<EOF
common --java_language_version=17
common --java_runtime_version=17
common --tool_java_language_version=17
common --tool_java_runtime_version=17
EOF

  cat > BUILD.bazel <<'EOF'
load("@rules_android//rules:rules.bzl", "android_binary", "android_library")

android_binary(
    name = "app",
    manifest = "AndroidManifest.xml",
    srcs = ["Main.java"],
    deps = [":lib"],
)

android_library(
    name = "lib",
    srcs = ["Lib.java"],
)
EOF
  cat > AndroidManifest.xml <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.example">
  <application />
</manifest>
EOF
  echo 'package com.example; public class Main extends Lib {}' > Main.java
  echo 'package com.example; public class Lib {}' > Lib.java
}

function check_desugar_workers() {
  local workers="$1"
  local multiplex="$2"
  "${BIT_BAZEL_BINARY}" aquery 'mnemonic(Desugar, //:app)' \
    "--internal_persistent_android_dex_desugar=${workers}" \
    "--internal_persistent_multiplex_android_dex_desugar=${multiplex}" \
    --include_commandline=false --include_artifacts=false > "$TEST_log" 2>&1 || \
    fail "Desugar action query failed"

  expect_log 'Mnemonic: Desugar'
  expect_log 'supports-path-mapping: 1'
  if [[ "${workers}" == "true" ]]; then
    expect_log 'supports-workers: 1'
  else
    expect_not_log 'supports-workers'
  fi
  if [[ "${workers}" == "true" && "${multiplex}" == "true" ]]; then
    expect_log 'supports-multiplex-workers: 1'
  else
    expect_not_log 'supports-multiplex-workers'
  fi
}

function test_workers_disabled() {
  check_desugar_workers false false
}

function test_singleplex_workers() {
  check_desugar_workers true false
}

function test_multiplex_workers() {
  check_desugar_workers true true
}

function test_multiplex_without_workers() {
  check_desugar_workers false true
}

run_suite "Desugar worker flags"
