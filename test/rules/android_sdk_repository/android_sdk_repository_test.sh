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

# For these tests to run do the following:
#
#   1. Install an Android SDK from https://developer.android.com
#   2. Set the $ANDROID_HOME environment variable
#   3. Uncomment the line in WORKSPACE containing android_sdk_repository
#
# Note that if the environment is not set up as above android_integration_test
# will silently be ignored and will be shown as passing.

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

source "$(rlocation build_bazel_rules_android/test/bashunit/unittest.bash)" || \
  (echo >&2 "Failed to locate bashunit.sh" && exit 1)

source "$(rlocation build_bazel_rules_android/test/rules/android_sdk_repository/android_helper.sh)" || \
  (echo >&2 "Failed to locate android_helper.sh" && exit 1)

# Check that the empty BUILD file was created.
function test_android_sdk_repository_no_path_or_android_home() {
  cat >> WORKSPACE <<EOF
android_sdk_repository(
    name = "androidsdk",
)
EOF

  verify_no_android_sdk
  "${BIT_BAZEL_BINARY}" build @androidsdk//:files >& $TEST_log && fail "Should have failed" || true
  expect_log "Either the path attribute of android_sdk_repository"
}

function test_android_sdk_repository_path_from_attribute() {
  # Create android SDK
  local sdk_path="$(create_android_sdk_basic)"

  # Add to repository.
  cat >> WORKSPACE <<EOF
android_sdk_repository(
    name = "androidsdk",
    path = "${sdk_path}",
)
EOF

  # Verify the SDK is created correctly.
  verify_android_sdk
}

function test_android_sdk_repository_path_from_environment() {
  # Create android SDK
  local sdk_path="$(create_android_sdk_basic)"

  # Add to repository.
  cat >> WORKSPACE <<EOF
android_sdk_repository(
    name = "androidsdk",
)
EOF

  export ANDROID_HOME="${sdk_path}"
  # Verify the SDK is created correctly.
  verify_android_sdk
}

function test_android_sdk_repository_fails_invalid_path() {
  # Create an empty SDK directory.
  mkdir -p "$TEST_TMPDIR/android_sdk"

  # Add to repository with the invalid path
  cat >> WORKSPACE <<EOF
android_sdk_repository(
    name = "androidsdk",
    path = "$TEST_TMPDIR/android_sdk",
)
EOF

  "${BIT_BAZEL_BINARY}" build @androidsdk//:files >& $TEST_log && fail "Should have failed" || true
  expect_log "No Android SDK apis found in the Android SDK"
}

function test_build_tools_largest() {
  # create several build tools
  local sdk_path="$(create_android_sdk)"
  add_platforms "${sdk_path}" 31
  add_build_tools "${sdk_path}" 10.1.2 20.2.3 30.3.4

  # Add to repository.
  cat >> WORKSPACE <<EOF
android_sdk_repository(
    name = "androidsdk",
    path = "${sdk_path}",
)
EOF

  check_android_sdk_provider
  expect_log "build_tools_version: 30.3.4"
}

function test_api_level_default() {
  # create several api levels
  local sdk_path="$(create_android_sdk)"
  add_platforms "${sdk_path}" 31 23 45
  add_build_tools "${sdk_path}" 30.3.4

  # Add to repository.
  cat >> WORKSPACE <<EOF
android_sdk_repository(
    name = "androidsdk",
    path = "${sdk_path}",
)
EOF

  # Should be the largest API level available
  check_android_sdk_provider
  expect_log "api_level: 45"
}

function test_api_level_specific() {
  # create several api levels
  local sdk_path="$(create_android_sdk)"
  add_platforms "${sdk_path}" 31 23 45
  add_build_tools "${sdk_path}" 30.3.4

  # Add to repository.
  cat >> WORKSPACE <<EOF
android_sdk_repository(
    name = "androidsdk",
    path = "${sdk_path}",
    api_level = 31,
)
EOF

  check_android_sdk_provider
  expect_log "api_level: 31"
}

function test_api_level_specific_missing() {
  # create several api levels
  local sdk_path="$(create_android_sdk)"
  add_platforms "${sdk_path}" 31 23 45
  add_build_tools "${sdk_path}" 30.3.4

  # Add to repository.
  cat >> WORKSPACE <<EOF
android_sdk_repository(
    name = "androidsdk",
    path = "${sdk_path}",
    api_level = 30,
)
EOF

  "${BIT_BAZEL_BINARY}" build @androidsdk//:files >& $TEST_log && fail "Should have failed" || true
  expect_log "Android SDK api level 30 was requested but it is not installed"
}

run_suite "Android integration tests for SDK"
