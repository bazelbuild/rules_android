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

# Verify both Unix and Windows Java launcher names using manifest-only runfiles.
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

set -euo pipefail
script="$(rlocation "$1")"
runfiles_library="$(rlocation bazel_tools/tools/bash/runfiles/runfiles.bash)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export TOOL_LOG="$work/tools.log"

cat > "$work/tool" <<'TOOL'
#!/usr/bin/env bash
set -eu
basename "$0" >> "$TOOL_LOG"
while [[ $# -gt 0 ]]; do
  if [[ "$1" == --output ]]; then
    echo output > "$2"
    break
  fi
  shift
done
TOOL
chmod +x "$work/tool"
echo '--min-api 21' > "$work/params"
touch "$work/libs.jar" "$work/minify.pgcfg"

for suffix in '' .exe; do
  manifest="$work/MANIFEST"
  cat > "$manifest" <<MANIFEST
bazel_tools/tools/bash/runfiles/runfiles.bash $runfiles_library
rules_android/tools/android/build_java8_legacy_dex_params.txt $work/params
rules_android/tools/android/desugared_jdk_libs.jar $work/libs.jar
rules_android/tools/android/minify_desugar_jdk_libs.pgcfg $work/minify.pgcfg
MANIFEST
  for tool in d8 r8 tracereferences; do
    cp "$work/tool" "$work/$tool$suffix"
    echo "rules_android/tools/android/$tool$suffix $work/$tool$suffix" >> "$manifest"
  done
  export RUNFILES_DIR='' RUNFILES_MANIFEST_FILE="$manifest"
  : > "$TOOL_LOG"
  bash "$script" --android_jar "$work/libs.jar" --output "$work/dex.zip"
  test -s "$work/dex.zip"
  bash "$script" --android_jar "$work/libs.jar" --binary "$work/libs.jar" \
    --output "$work/shrunk.zip" --output_map "$work/map"
  test -s "$work/shrunk.zip"
  printf 'd8%s\ntracereferences%s\nr8%s\n' "$suffix" "$suffix" "$suffix" > "$work/expected"
  diff "$work/expected" "$TOOL_LOG"
  rm "$work/dex.zip" "$work/shrunk.zip"
done
