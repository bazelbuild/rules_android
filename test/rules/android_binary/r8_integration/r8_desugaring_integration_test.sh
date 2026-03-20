#!/bin/bash
#
# Copyright 2024 The Bazel Authors. All rights reserved.
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

# Integration tests for R8 desugaring with and without --desugar_java8_libs.
#
# These tests verify that:
# 1. When --desugar_java8_libs is enabled, R8 rewrites java.* calls to j$.*
#    backports AND the j$.* implementation classes are included in the APK.
# 2. When --nodesugar_java8_libs is set, no j$.* classes appear in the APK
#    and java.* calls remain as-is.
# 3. DurationUser is retained in both cases (proguard keep rule).

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

source "$(rlocation rules_android/test/rules/android_binary/r8_integration/r8_desugaring_helper.sh)" || \
  (echo >&2 "Failed to locate r8_desugaring_helper.sh" && exit 1)

# Test: with --desugar_java8_libs enabled, R8 desugars java.time APIs and the
# backport implementation classes (j$.*) are included in the APK.
function test_desugaring_enabled() {
  build_desugaring_app --desugar_java8_libs

  # DurationUser must be retained by proguard keep rules.
  apk_dex_contains 'Lcom/desugaring/test/DurationUser;' || \
    fail "DurationUser class not found in DEX"

  # Duration.toSeconds() (API 31) must be desugared: the raw java.time
  # invocation is rewritten to a j$.time backport, so the original
  # method reference should not appear in the constant pool.
  if apk_dex_contains 'java/time/Duration;.*toSeconds'; then
    fail "Expected Duration.toSeconds() to be desugared but raw java/time reference found"
  fi

  # The j$.* backport implementation classes must be present. Without them
  # the app crashes at runtime with NoClassDefFoundError (e.g. j$/net/URLEncoder).
  apk_dex_contains 'Lj\$/' || \
    fail "Expected j\$.* desugared library classes in the APK"
}

# Test: with --nodesugar_java8_libs, R8 does not rewrite java.* references
# and no desugared library DEX is appended.
function test_desugaring_disabled() {
  build_desugaring_app --nodesugar_java8_libs

  # DurationUser must still be retained regardless of the desugaring flag.
  apk_dex_contains 'Lcom/desugaring/test/DurationUser;' || \
    fail "DurationUser class not found in DEX"

  # Without desugaring, java.time.Duration.toSeconds() remains as a direct
  # call in the DEX. (It will crash on API < 31 devices, but the reference
  # should be present.)
  apk_dex_contains 'java/time/Duration' || \
    fail "Expected raw java/time/Duration reference when desugaring is disabled"

  # No j$.* classes should be present.
  if apk_dex_contains 'Lj\$/'; then
    fail "Unexpected j\$.* desugared library classes when desugaring is disabled"
  fi
}

run_suite "R8 desugaring integration tests"
