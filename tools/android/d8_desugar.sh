#!/bin/bash
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

# A wrapper around the d8 desugar binary that pass the r8 json config file.

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

# exit on errors and uninitialized variables
set -eu

readonly TMPDIR="$(mktemp -d)"
trap "rm -rf ${TMPDIR}" EXIT

declare -a ARGS_FROM_PARAMS_FILE
PARAMS_TXT=$(rlocation rules_android/tools/android/d8_desugar_params.txt)
read -ra ARGS_FROM_PARAMS_FILE <<< "$(cat $PARAMS_TXT)"
DESUGAR_JDK_LIBS_JSON="$(rlocation rules_android/tools/android/full_desugar_jdk_libs_config.json)"
readonly DESUGAR_CONFIG=("${ARGS_FROM_PARAMS_FILE[@]}" --desugared_lib_config "$DESUGAR_JDK_LIBS_JSON")

DESUGAR_BINARY="$(rlocation bazel_tools/src/tools/android/java/com/google/devtools/build/android/r8/desugar)"

# Check for params file.  Desugar doesn't accept a mix of params files and flags
# directly on the command line, so we need to build a new params file that adds
# the flags we want.
if [[ "$#" -gt 0 ]]; then
  arg="$1";
  case "${arg}" in
    @*)
      params="${TMPDIR}/desugar.params"
      cat "${arg:1}" > "${params}"  # cp would create file readonly
      for o in "${DESUGAR_CONFIG[@]}"; do
        echo "${o}" >> "${params}"
      done
      "$DESUGAR_BINARY" \
          "@${params}"
      # temp dir deleted by TRAP installed above
      exit 0
    ;;
  esac
fi

# Some unit tests pass an explicit --desugared_lib_config, in that case don't
# add the default one.
has_desugared_lib_config=false
for arg in "$@"; do
  if [[ "$arg" == "--desugared_lib_config" ]]; then
    has_desugared_lib_config=true
  fi
done

if [[ "$has_desugared_lib_config" == "true" ]]; then
  "$DESUGAR_BINARY" \
      "$@"
else
  "$DESUGAR_BINARY" \
      "$@" \
      "${DESUGAR_CONFIG[@]}"
fi

