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

# Shared helper functions for the Bazel path mapping
# (--experimental_output_paths=strip) integration tests.

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

_WORKSPACE_INITIALIZED=false

APP_TARGET="//app:app"
APK_PATH="bazel-bin/app/app.apk"

# The fixed configuration segment Bazel rewrites output paths to under path mapping.
STRIPPED_SEGMENT="bazel-out/cfg/bin"
# Matches a real (non-stripped) configuration output root, e.g. bazel-out/darwin_arm64-fastbuild/bin
# or bazel-out/k8-opt-exec-.../bin. A real config segment always contains a "-"; the stripped
# segment ("cfg") never does, so this never matches STRIPPED_SEGMENT.
REAL_CONFIG_RE="bazel-out/[a-zA-Z0-9_]+-[a-zA-Z0-9_.-]*/bin"

# Resolve the real filesystem path of the rules_android source tree.
function get_rules_android_path() {
  local module_bazel="$(rlocation rules_android/MODULE.bazel)"
  if [[ -z "${module_bazel}" || ! -f "${module_bazel}" ]]; then
    fail "Failed to locate rules_android MODULE.bazel"
  fi
  local real_path
  real_path="$(python3 -c "import os; print(os.path.realpath('${module_bazel}'))")"
  dirname "${real_path}"
}

# set_up is called before each test by bashunit. We only initialize the workspace once since the
# inner Bazel build is expensive. Subsequent tests reuse the same workspace and inner Bazel server.
function set_up() {
  if [[ "${_WORKSPACE_INITIALIZED}" == "true" ]]; then
    return
  fi
  _WORKSPACE_INITIALIZED=true

  # Clean out the workspace.
  rm -rf *

  local rules_dir="$(get_rules_android_path)"
  local sdk_path="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -z "${sdk_path}" ]]; then
    fail "ANDROID_HOME or ANDROID_SDK_ROOT must be set"
  fi

  create_workspace "${rules_dir}" "${sdk_path}"
  create_app
}

function create_workspace() {
  local rules_dir="$1"
  local sdk_path="$2"

  cat > MODULE.bazel <<EOF
module(name = "path_mapping_integration_test")

bazel_dep(name = "rules_java", version = "9.3.0")
bazel_dep(name = "bazel_skylib", version = "1.8.1")
bazel_dep(name = "rules_android", version = "0.7.1")

local_path_override(
    module_name = "rules_android",
    path = "${rules_dir}",
)

remote_android_extensions = use_extension(
    "@rules_android//bzlmod_extensions:android_extensions.bzl",
    "remote_android_tools_extensions")
use_repo(remote_android_extensions, "android_tools")

android_sdk_repository_extension = use_extension(
    "@rules_android//rules/android_sdk_repository:rule.bzl",
    "android_sdk_repository_extension")
android_sdk_repository_extension.configure(path = "${sdk_path}")
use_repo(android_sdk_repository_extension, "androidsdk")

register_toolchains("@androidsdk//:sdk-toolchain", "@androidsdk//:all")
EOF

  cat > .bazelrc <<EOF
common --noenable_workspace
common --enable_bzlmod
common --java_language_version=17
common --java_runtime_version=17
common --tool_java_language_version=17
common --tool_java_runtime_version=17
common --repositories_without_autoloads=bazel_features_version,bazel_features_globals,cc_compatibility_proxy
EOF
}

# Creates an android_binary that exercises the path-mapped pipeline end to end:
#   * an android_library dependency with its own resources + assets (resource compile/merge/link,
#     R-class and AAR generation, manifest merge across a dep edge),
#   * java.time usage so the Desugar action runs,
#   * multidex = "native" so the dexing + dex-merge actions run.
function create_app() {
  mkdir -p lib/res/values lib/assets app/res/values app/res/layout

  # --- android_library with resources, assets and a java.time-using class ---
  cat > lib/res/values/strings.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="lib_string">from lib</string>
</resources>
EOF

  cat > lib/assets/data.txt <<'EOF'
lib-asset-content
EOF

  cat > lib/Greeter.java <<'EOF'
package com.test.lib;

import java.time.Duration;

public class Greeter {
    public static long seconds(int minutes) {
        return Duration.ofMinutes(minutes).toSeconds();
    }
}
EOF

  cat > lib/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test.lib">
    <application />
</manifest>
EOF

  cat > lib/BUILD <<'EOF'
load("@rules_android//rules:rules.bzl", "android_library")

android_library(
    name = "lib",
    srcs = ["Greeter.java"],
    manifest = "AndroidManifest.xml",
    custom_package = "com.test.lib",
    assets = ["assets/data.txt"],
    assets_dir = "assets",
    resource_files = glob(["res/**"]),
    visibility = ["//visibility:public"],
)
EOF

  # --- android_binary depending on the library ---
  cat > app/res/values/strings.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">PathMappingTest</string>
</resources>
EOF

  cat > app/res/layout/activity_main.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
EOF

  cat > app/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test.app">
    <application>
        <activity android:name=".MainActivity"
                  android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

  cat > app/MainActivity.java <<'EOF'
package com.test.app;

import android.app.Activity;
import android.os.Bundle;
import com.test.lib.Greeter;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setTitle("Seconds: " + Greeter.seconds(5));
    }
}
EOF

  cat > app/BUILD <<'EOF'
load("@rules_android//rules:rules.bzl", "android_binary")

android_binary(
    name = "app",
    srcs = ["MainActivity.java"],
    manifest = "AndroidManifest.xml",
    multidex = "native",
    resource_files = glob(["res/**"]),
    deps = ["//lib"],
)
EOF
}

# Builds the app, printing every executed action's command line via --subcommands to the given log.
# Usage: build_app <log_file> [extra bazel flags...]
function build_app() {
  local log_file="$1"
  shift
  "${BIT_BAZEL_BINARY}" build --subcommands=pretty_print "$@" -- ${APP_TARGET} \
    >"${log_file}" 2>&1 || {
      echo "----- inner build output -----" >&2
      cat "${log_file}" >&2
      fail "Failed to build ${APP_TARGET} (flags: $*)"
    }
}

# Prints the --subcommands block(s) (from the "SUBCOMMAND:" header until the next one) whose header
# contains the given needle, so callers can assert on a single action's executed command line.
# Usage: action_block <log_file> <header_needle>
function action_block() {
  local log_file="$1"
  local needle="$2"
  awk -v needle="${needle}" '
    index($0, "SUBCOMMAND:") == 1 { capture = (index($0, needle) > 0) }
    capture
  ' "${log_file}"
}

# Asserts that the given action ran AND every output-tree path in its command line was rewritten to
# the stripped (bazel-out/cfg/bin) segment, i.e. it contains no real configuration segment.
# Usage: assert_action_stripped <log_file> <header_needle>
function assert_action_stripped() {
  local log_file="$1"
  local needle="$2"
  local block
  block="$(action_block "${log_file}" "${needle}")"
  [[ -n "${block}" ]] || fail "Action matching '${needle}' did not run; cannot verify path stripping"
  echo "${block}" | grep -q "${STRIPPED_SEGMENT}" || \
    fail "Action '${needle}' should use stripped paths (${STRIPPED_SEGMENT}) under path mapping"
  if echo "${block}" | grep -qE "${REAL_CONFIG_RE}"; then
    fail "Action '${needle}' still references a real configuration segment under path mapping; not fully stripped"
  fi
}

# Asserts that the given action ran AND uses real (non-stripped) configuration paths, i.e. path
# mapping did NOT rewrite it. Used for the baseline (no --experimental_output_paths=strip) build.
# Usage: assert_action_not_stripped <log_file> <header_needle>
function assert_action_not_stripped() {
  local log_file="$1"
  local needle="$2"
  local block
  block="$(action_block "${log_file}" "${needle}")"
  [[ -n "${block}" ]] || fail "Action matching '${needle}' did not run; cannot verify baseline paths"
  echo "${block}" | grep -qE "${REAL_CONFIG_RE}" || \
    fail "Action '${needle}' should reference a real configuration path in the baseline build"
  if echo "${block}" | grep -q "${STRIPPED_SEGMENT}"; then
    fail "Action '${needle}' must NOT contain stripped (${STRIPPED_SEGMENT}) paths without --experimental_output_paths=strip"
  fi
}
