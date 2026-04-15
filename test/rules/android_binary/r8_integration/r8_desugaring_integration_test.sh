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

  apk_dex_contains 'Lcom/test/app/TimeUnitUser;' || \
    fail "TimeUnitUser class not found in DEX"

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

# Test: with minSdkVersion=28 and --desugar_java8_libs, R8 must still apply
# java.time type rewriting (java.time.* → j$.time.*) so that retargeted call
# signatures match the pre-built desugar library.
#
# Without the fix (capping R8's --min-api to DEPOT_FLOOR when --desugared-lib is
# used), R8 at --min-api 28 considers java.time available and skips type
# rewriting. This creates a signature mismatch: retargeted calls use
# java.time.Duration but the desugar library defines methods with
# j$.time.Duration → NoSuchMethodError at runtime.
function test_desugaring_with_high_min_sdk_rewrites_java_time() {
  build_high_min_sdk_app --desugar_java8_libs

  # With correct desugaring, ALL java.time references must be rewritten to
  # j$.time — even though java.time is natively available at API 28. This is
  # required because the pre-built desugar library uses j$.time types in its
  # method signatures.
  if high_min_sdk_apk_dex_contains 'java/time/Duration'; then
    fail "java/time/Duration found in DEX with minSdkVersion=28. " \
         "R8 did not rewrite java.time types to j\$.time, which will cause " \
         "NoSuchMethodError when calling desugared methods like " \
         "DesugarTimeUnit.convert() or DesugarDuration.toSeconds()."
  fi

  # j$.time.Duration must be present (the rewritten type).
  high_min_sdk_apk_dex_contains 'j\$/time/Duration' || \
    fail "j\$/time/Duration not found in DEX — java.time type rewriting not applied"

  # Desugar library backport classes must be included.
  high_min_sdk_apk_dex_contains 'Lj\$/' || \
    fail "Expected j\$.* desugared library classes in the APK"
}

# Test: with minSdkVersion=28, TimeUnit.convert(Duration) (added in API 33)
# must be desugared — the raw platform reference must not appear.
function test_desugaring_with_high_min_sdk_timeunit_convert() {
  build_high_min_sdk_app --desugar_java8_libs

  high_min_sdk_apk_dex_contains 'Lcom/test/app/TimeUnitUser;' || \
    fail "TimeUnitUser class not found in DEX"

  # The raw TimeUnit.convert reference must be absent (retargeted to
  # DesugarTimeUnit.convert by the desugaring config).
  if high_min_sdk_apk_dex_contains 'TimeUnit;.*convert.*Duration'; then
    fail "Raw TimeUnit.convert(Duration) reference found in DEX with " \
         "minSdkVersion=28. Expected it to be desugared."
  fi
}

run_suite "R8 desugaring integration tests"
