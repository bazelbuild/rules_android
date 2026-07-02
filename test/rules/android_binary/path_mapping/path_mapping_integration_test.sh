#!/bin/bash
#
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

# Integration tests for Bazel path mapping (--experimental_output_paths=strip) compatibility.
#
# The same android_binary (exercising the resource busybox, manifest merge, R-class/AAR generation,
# desugaring and dexing actions we opted into path mapping) is built twice and the executed command
# lines (captured via --subcommands) are inspected per action:
#
#   * WITH stripping: each opted-in action's command must be rewritten entirely to the fixed
#     "bazel-out/cfg/bin" segment (no real configuration segment remains). This proves the action
#     is genuinely path-mapping compatible -- an action whose command embedded an unmapped path
#     would also fail to build, since its tool would look for inputs at the wrong location.
#
#   * WITHOUT stripping (baseline control): the same actions must use the real configuration
#     segment (e.g. bazel-out/darwin_arm64-fastbuild/bin) and contain NO "bazel-out/cfg/bin",
#     confirming the stripping above is caused by the flag and not something else.

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

source "$(rlocation rules_android/test/rules/android_binary/path_mapping/path_mapping_helper.sh)" || \
  (echo >&2 "Failed to locate path_mapping_helper.sh" && exit 1)

# Progress-message substrings identifying each opted-in action in the --subcommands output.
_RESOURCE_ACTION="Packaging Android Resources"
_DESUGAR_ACTION="Desugaring"
_DEX_ACTION="Dexing"

_STRIP_LOG=""
_BASELINE_LOG=""

# Builds the app once with path mapping enabled (memoized across tests). Path mapping requires a
# sandboxing-capable strategy and a cache.
function ensure_stripped_build() {
  if [[ -n "${_STRIP_LOG}" ]]; then
    return
  fi
  _STRIP_LOG="${TEST_TMPDIR}/strip.subcommands.log"
  build_app "${_STRIP_LOG}" \
    --experimental_output_paths=strip \
    --spawn_strategy=sandboxed \
    --disk_cache="${TEST_TMPDIR}/strip_cache" \
    --desugar_java8_libs
}

# Builds the app once WITHOUT path mapping (memoized across tests) as the control.
function ensure_baseline_build() {
  if [[ -n "${_BASELINE_LOG}" ]]; then
    return
  fi
  _BASELINE_LOG="${TEST_TMPDIR}/baseline.subcommands.log"
  build_app "${_BASELINE_LOG}" --desugar_java8_libs
}

# Both builds produce an APK. Building with stripping on is the core compatibility signal.
function test_builds_succeed() {
  ensure_baseline_build
  ensure_stripped_build
  [[ -f "${APK_PATH}" ]] || fail "Expected APK at ${APK_PATH} after the path-mapped build"
}

# WITH stripping: the resource, desugar and dexing actions' output paths are stripped to cfg.
function test_resource_action_outputs_stripped() {
  ensure_stripped_build
  assert_action_stripped "${_STRIP_LOG}" "${_RESOURCE_ACTION}"
}

function test_desugar_action_outputs_stripped() {
  ensure_stripped_build
  assert_action_stripped "${_STRIP_LOG}" "${_DESUGAR_ACTION}"
}

function test_dex_action_outputs_stripped() {
  ensure_stripped_build
  assert_action_stripped "${_STRIP_LOG}" "${_DEX_ACTION}"
}

# WITHOUT stripping (baseline): the same actions use real configuration paths and nothing is
# rewritten to cfg. This is the control that the stripping above is caused by the flag.
function test_baseline_has_no_stripped_paths() {
  ensure_baseline_build
  grep -qE "${REAL_CONFIG_RE}" "${_BASELINE_LOG}" || \
    fail "Baseline build should reference real configuration output paths"
  if grep -q "${STRIPPED_SEGMENT}" "${_BASELINE_LOG}"; then
    fail "Baseline build (no --experimental_output_paths=strip) must NOT contain stripped ${STRIPPED_SEGMENT} paths"
  fi
}

function test_baseline_resource_action_uses_real_config_paths() {
  ensure_baseline_build
  assert_action_not_stripped "${_BASELINE_LOG}" "${_RESOURCE_ACTION}"
}

function test_baseline_dex_action_uses_real_config_paths() {
  ensure_baseline_build
  assert_action_not_stripped "${_BASELINE_LOG}" "${_DEX_ACTION}"
}

run_suite "Bazel path mapping integration tests"
