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

# Shared helper functions for R8 integration tests (desugaring + Java resources).

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

APP_TARGET="//app"
APK_PATH="bazel-bin/app/app.apk"
OBFUSCATED_APP_TARGET="//app:app_obfuscated"
OBFUSCATED_APK_PATH="bazel-bin/app/app_obfuscated.apk"
HIGH_MIN_SDK_APP_TARGET="//app:app_high_min_sdk"
HIGH_MIN_SDK_APK_PATH="bazel-bin/app/app_high_min_sdk.apk"

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

# set_up is called before each test by bashunit. We only initialize the
# workspace once since the inner Bazel build is expensive. Subsequent tests
# reuse the same workspace and inner Bazel server.
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
module(name = "r8_integration_test")

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

# Creates a single test app that exercises both java.time desugaring (via
# DurationUser) and Java resource preservation (via lib_with_resources).
function create_app() {
  mkdir -p app/res/layout app/res/values
  mkdir -p lib/com/test/data
  mkdir -p spi/META-INF/services

  # --- Library with a Java resource file ---
  cat > lib/com/test/data/metadata.txt <<'EOF'
test-metadata-content
EOF

  cat > lib/ResourceReader.java <<'EOF'
package com.test.lib;

import java.io.InputStream;

public class ResourceReader {
    public static String getMetadata() {
        InputStream is = ResourceReader.class.getClassLoader()
            .getResourceAsStream("com/test/data/metadata.txt");
        return is != null ? "found" : "missing";
    }
}
EOF

  cat > lib/BUILD <<'EOF'
load("@rules_java//java:java_library.bzl", "java_library")

java_library(
    name = "lib_with_resources",
    srcs = ["ResourceReader.java"],
    resources = ["com/test/data/metadata.txt"],
    resource_strip_prefix = "lib",
    visibility = ["//visibility:public"],
)
EOF

  # --- ServiceLoader library (interface + impl + META-INF/services) ---
  cat > spi/MyService.java <<'EOF'
package com.test.spi;

public interface MyService {
    String getName();
}
EOF

  cat > spi/MyServiceImpl.java <<'EOF'
package com.test.spi;

public class MyServiceImpl implements MyService {
    @Override
    public String getName() {
        return "impl";
    }
}
EOF

  cat > spi/META-INF/services/com.test.spi.MyService <<'EOF'
com.test.spi.MyServiceImpl
EOF

  cat > spi/BUILD <<'EOF'
load("@rules_java//java:java_library.bzl", "java_library")

java_library(
    name = "spi_lib",
    srcs = ["MyService.java", "MyServiceImpl.java"],
    resources = ["META-INF/services/com.test.spi.MyService"],
    resource_strip_prefix = "spi",
    visibility = ["//visibility:public"],
)
EOF

  # --- App using java.time APIs, resource library, and ServiceLoader ---
  cat > app/BUILD <<'EOF'
load("@rules_android//rules:rules.bzl", "android_binary")

_COMMON_SRCS = [
    "MainActivity.java",
    "DurationUser.java",
    "TimeUnitUser.java",
    "ServiceUser.java",
]

_COMMON_DEPS = [
    "//lib:lib_with_resources",
    "//spi:spi_lib",
]

android_binary(
    name = "app",
    srcs = _COMMON_SRCS,
    manifest = "AndroidManifest.xml",
    proguard_specs = ["proguard.cfg"],
    resource_files = glob(["res/**"]),
    deps = _COMMON_DEPS,
)

android_binary(
    name = "app_obfuscated",
    srcs = _COMMON_SRCS,
    manifest = "AndroidManifest.xml",
    proguard_specs = ["proguard_obfuscated.cfg"],
    resource_files = glob(["res/**"]),
    deps = _COMMON_DEPS,
)

# App with minSdkVersion=28 — exercises the code path where R8's --min-api
# must be capped to DEPOT_FLOOR for correct core library desugaring. Without
# the cap, java.time types are not rewritten to j$.time (since java.time is
# natively available at API 26+), but the pre-built desugar library uses
# j$.time types, causing a signature mismatch and NoSuchMethodError at runtime.
android_binary(
    name = "app_high_min_sdk",
    srcs = _COMMON_SRCS,
    manifest = "AndroidManifest.xml",
    manifest_values = {"minSdkVersion": "28"},
    proguard_specs = ["proguard.cfg"],
    resource_files = glob(["res/**"]),
    deps = _COMMON_DEPS,
)
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
import com.test.lib.ResourceReader;
import java.time.Duration;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Duration d = Duration.ofMinutes(5);
        long seconds = DurationUser.getSeconds(d);
        long converted = TimeUnitUser.convertDuration(d);
        String svc = ServiceUser.loadService();
        setTitle("s=" + seconds + " c=" + converted + " r=" + ResourceReader.getMetadata() + " svc=" + svc);
    }
}
EOF

  cat > app/DurationUser.java <<'EOF'
package com.test.app;

import java.time.Duration;

public class DurationUser {
    public static long getSeconds(Duration duration) {
        return duration.toSeconds();
    }
}
EOF

  cat > app/TimeUnitUser.java <<'EOF'
package com.test.app;

import java.time.Duration;
import java.util.concurrent.TimeUnit;

public class TimeUnitUser {
    public static long convertDuration(Duration duration) {
        return TimeUnit.SECONDS.convert(duration);
    }
}
EOF

  cat > app/ServiceUser.java <<'EOF'
package com.test.app;

import com.test.spi.MyService;
import java.util.ServiceLoader;

public class ServiceUser {
    public static String loadService() {
        ServiceLoader<MyService> loader = ServiceLoader.load(MyService.class);
        for (MyService svc : loader) {
            return svc.getName();
        }
        return "none";
    }
}
EOF

  cat > app/proguard.cfg <<'EOF'
-dontobfuscate
-keep class com.test.app.MainActivity { *; }
-keep class com.test.app.DurationUser { *; }
-keep class com.test.app.TimeUnitUser { *; }
-keep class com.test.app.ServiceUser { *; }
-keep class com.test.lib.ResourceReader { *; }
EOF

  # Proguard config WITH obfuscation — lets R8 rename service interfaces.
  # -dontoptimize prevents R8 from inlining ServiceLoader calls, ensuring
  # META-INF/services files are preserved (but renamed to match obfuscated names).
  cat > app/proguard_obfuscated.cfg <<'EOF'
-dontoptimize
-keep class com.test.app.MainActivity { *; }
-keep class com.test.app.DurationUser { *; }
-keep class com.test.app.ServiceUser { *; }
-keep class com.test.lib.ResourceReader { *; }
EOF

  cat > app/res/layout/activity_main.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
EOF

  cat > app/res/values/strings.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">R8IntegrationTest</string>
</resources>
EOF
}

# Build the app with extra Bazel flags.
# Usage: build_app [--desugar_java8_libs | --nodesugar_java8_libs]
function build_app() {
  "${BIT_BAZEL_BINARY}" build "$@" -- ${APP_TARGET} >& $TEST_log || \
    fail "Failed to build ${APP_TARGET}"
}

# Build the obfuscated app (R8 renaming enabled) with extra Bazel flags.
# Usage: build_obfuscated_app [--desugar_java8_libs | --nodesugar_java8_libs]
function build_obfuscated_app() {
  "${BIT_BAZEL_BINARY}" build "$@" -- ${OBFUSCATED_APP_TARGET} >& $TEST_log || \
    fail "Failed to build ${OBFUSCATED_APP_TARGET}"
}

# Build the high-min-sdk app (minSdkVersion=28) with extra Bazel flags.
# Usage: build_high_min_sdk_app [--desugar_java8_libs | --nodesugar_java8_libs]
function build_high_min_sdk_app() {
  "${BIT_BAZEL_BINARY}" build "$@" -- ${HIGH_MIN_SDK_APP_TARGET} >& $TEST_log || \
    fail "Failed to build ${HIGH_MIN_SDK_APP_TARGET}"
}

# Returns 0 if any dex in the given APK contains a string matching the pattern.
# Usage: _apk_dex_contains_at <apk_path> <grep_pattern>
function _apk_dex_contains_at() {
  local apk_path="$1"
  local pattern="$2"
  if [[ ! -f "${apk_path}" ]]; then
    echo "APK not found at ${apk_path}" >&2
    return 1
  fi

  local tmpdir=$(mktemp -d)
  unzip -o "${apk_path}" '*.dex' -d "${tmpdir}" > /dev/null 2>&1

  local found=false
  for dex in "${tmpdir}"/classes*.dex; do
    if [[ -f "${dex}" ]] && strings "${dex}" | grep -q "${pattern}"; then
      found=true
      break
    fi
  done

  rm -rf "${tmpdir}"
  [[ "${found}" == "true" ]]
}

# Returns 0 if any dex in the APK contains a string matching the given pattern.
# Usage: apk_dex_contains <grep_pattern>
function apk_dex_contains() {
  _apk_dex_contains_at "${APK_PATH}" "$1"
}

# Returns 0 if any dex in the high-min-sdk APK contains a string matching the pattern.
# Usage: high_min_sdk_apk_dex_contains <grep_pattern>
function high_min_sdk_apk_dex_contains() {
  _apk_dex_contains_at "${HIGH_MIN_SDK_APK_PATH}" "$1"
}

# Returns 0 if the APK contains a file matching the given path.
# Usage: apk_contains_file <path>
function apk_contains_file() {
  local path="$1"
  if [[ ! -f "${APK_PATH}" ]]; then
    echo "APK not found at ${APK_PATH}" >&2
    return 1
  fi

  ( set +o pipefail; zipinfo -1 "${APK_PATH}" 2>/dev/null | grep -q "${path}" )
}

# Returns 0 if the given file path exists in the obfuscated APK.
# Usage: obfuscated_apk_contains_file <path>
function obfuscated_apk_contains_file() {
  local path="$1"
  if [[ ! -f "${OBFUSCATED_APK_PATH}" ]]; then
    echo "APK not found at ${OBFUSCATED_APK_PATH}" >&2
    return 1
  fi

  ( set +o pipefail; zipinfo -1 "${OBFUSCATED_APK_PATH}" 2>/dev/null | grep -q "${path}" )
}
