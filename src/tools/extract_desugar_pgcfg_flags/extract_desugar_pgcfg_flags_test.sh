#!/bin/bash
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

# Basic end-to-end test for extracting pgcfg flags from desugarer JSON config.

BINARY_UNDER_TEST=
function ParseArgs() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      "--binary_under_test")
        BINARY_UNDER_TEST="$2"
        shift
        ;;
      *)
        die "Unknown argument '$1'"
        ;;
    esac

    shift
  done
}

# Test setup: get path to binary under test
ParseArgs "$@"
readonly BINARY_UNDER_TEST

set -euxo pipefail

# Create dummy data
dummy_json_file="$(mktemp)"
# Dummy data: shrinker_config is a list of strings, and another unrelated field.
echo "{\"shrinker_config\": [\"a\", \"b\", \"c\"], \"foo\": \"bar\"}" > "$dummy_json_file"

# Dummy output dummy output file
test_output_file="$(mktemp)"
expected_output_file="$(mktemp)"
# Expected outcome is a\nb\nc
echo -ne "a\nb\nc" > "$expected_output_file"

# Run the binary on the test data
"$BINARY_UNDER_TEST" --input_json "$dummy_json_file" --output_file "$test_output_file"

# Expect the files to be the same
diff "$test_output_file" "$expected_output_file"

echo "PASS"
