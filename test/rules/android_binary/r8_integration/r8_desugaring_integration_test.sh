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

# Integration tests for R8 desugaring and Java resource preservation.

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

source "$(rlocation rules_android/test/rules/android_binary/r8_integration/r8_integration_helper.sh)" || \
  (echo >&2 "Failed to locate r8_integration_helper.sh" && exit 1)

# Test: with --desugar_java8_libs enabled, R8 desugars java.time APIs and the
# backport implementation classes (j$.*) are included in the APK.
function test_desugaring_enabled() {
  build_app --desugar_java8_libs

  apk_dex_contains 'Lcom/test/app/DurationUser;' || \
    fail "DurationUser class not found in DEX"

  if apk_dex_contains 'java/time/Duration;.*toSeconds'; then
    fail "Expected Duration.toSeconds() to be desugared but raw java/time reference found"
  fi

  apk_dex_contains 'Lj\$/' || \
    fail "Expected j\$.* desugared library classes in the APK"
}

# Test: with --nodesugar_java8_libs, R8 does not rewrite java.* references
# and no desugared library DEX is appended.
function test_desugaring_disabled() {
  build_app --nodesugar_java8_libs

  apk_dex_contains 'Lcom/test/app/DurationUser;' || \
    fail "DurationUser class not found in DEX"

  apk_dex_contains 'java/time/Duration' || \
    fail "Expected raw java/time/Duration reference when desugaring is disabled"

  if apk_dex_contains 'Lj\$/'; then
    fail "Unexpected j\$.* desugared library classes when desugaring is disabled"
  fi
}

# Test: with --desugar_java8_libs enabled, Java resources from dependency JARs
# must be present in the final APK.
function test_java_resources_preserved_with_desugaring() {
  build_app --desugar_java8_libs

  apk_contains_file 'com/test/data/metadata.txt' || \
    fail "Java resource 'com/test/data/metadata.txt' not found in APK. " \
         "DexReducer likely stripped non-.dex entries and java_resource_jar was not set."
}

# Test: without desugaring, Java resources should also be preserved.
function test_java_resources_preserved_without_desugaring() {
  build_app --nodesugar_java8_libs

  apk_contains_file 'com/test/data/metadata.txt' || \
    fail "Java resource 'com/test/data/metadata.txt' not found in APK even without desugaring."
}

# Test: with obfuscation + desugaring, META-INF/services entries must come from
# R8's processed output (with obfuscated names), not the unprocessed deploy jar.
# Reproduces a crash where DexReducer strips R8's correctly renamed service
# files and the deploy jar provides originals that don't match obfuscated DEX.
function test_serviceloader_metadata_consistent_with_dex_when_desugaring() {
  build_obfuscated_app --desugar_java8_libs

  # R8 renames MyService during obfuscation, so the original service filename
  # must NOT appear in the APK. If it does, resources came from the unprocessed
  # deploy jar instead of R8's output.
  if obfuscated_apk_contains_file 'META-INF/services/com.test.spi.MyService'; then
    fail "APK contains META-INF/services/com.test.spi.MyService with original class name. " \
         "java_resource_jar likely points to the unprocessed deploy jar instead of R8 output."
  fi

  # Verify at least one META-INF/services entry exists (R8's renamed version).
  obfuscated_apk_contains_file 'META-INF/services/' || \
    fail "No META-INF/services entries found in APK."
}

run_suite "R8 desugaring integration tests"
