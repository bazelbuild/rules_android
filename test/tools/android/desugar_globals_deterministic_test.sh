#!/usr/bin/env bash
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

# Verify the genrules that run the R8 global synthetics generator set
# deterministicdebugging. Without it the entry order of the output zip varies
# between runs.

set -euo pipefail

rules="$1"
flag="-Dcom.android.tools.r8.deterministicdebugging=1"

for name in desugar_globals desugar_globals_classes; do
  # Keep only the lines of this genrule: from its name to the next rule.
  cmd="$(awk -v n="name = \"${name}\"" '
    /^genrule\(/ { in_rule = 0 }
    index($0, n) { in_rule = 1 }
    in_rule && /cmd = / { print }
  ' "$rules")"
  if [[ -z "$cmd" ]]; then
    echo "FAIL: no cmd found for //tools/android:${name}" >&2
    exit 1
  fi
  if [[ "$cmd" != *"$flag"* ]]; then
    echo "FAIL: //tools/android:${name} does not pass ${flag}" >&2
    echo "$cmd" >&2
    exit 1
  fi
done
echo "PASS"
