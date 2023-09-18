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

function DownloadBazelisk()  {
  # Utility function to download a specified version of bazelisk to a given
  # installation directory. Adds the directory to PATH.
  # Positional arguments:
  #   version: The version to install.
  #   platform: The platform to install. Currently only "linux" has been
  #     validated.
  #   arch: Architecture to install. Currently only "arm64" has been validated.
  #   dest: Where to install Bazelisk. Must be a user-writeable directory,
  #     otherwise the root user must call this function through sudo.
  (
    set -euxo pipefail

    # Positional arguments
    local version="${1:-1.18.0}"
    local platform="${2:-linux}"
    local arch="${3:-amd64}"
    local dest="${4:-${TMPDIR}/bazelisk-release}"

    download_url="https://github.com/bazelbuild/bazelisk/releases/download/v${version}/bazelisk-${platform}-${arch}"
    mkdir -p "${dest}"
    wget -nv ${download_url} -O "${dest}/bazelisk"
    chmod +x "${dest}/bazelisk"
    ln -s "${dest}/bazelisk" "${dest}/bazel"
    export PATH="${dest}:${PATH}"
    type -a bazel
    echo "Bazelisk ${version} installation completed."
  )
}

function main() {
  set -euxo pipefail
  echo "== installing bazelisk ========================================="
  bazel_install_dir=$(mktemp -d)
  BAZELISK_VERSION="1.18.0"
  export USE_BAZEL_VERSION="last_green"
  DownloadBazelisk "$BAZELISK_VERSION" linux amd64 "$bazel_install_dir"
  bazel="$bazel_install_dir/bazel"
  echo "============================================================="

  function Cleanup() {
    # Clean up all temporary directories: bazelisk install, sandbox, and
    # android_tools.
    rm -rf "$bazel_install_dir"
  }
  trap Cleanup EXIT

  function cd () {
    # This is necessary due to a weird docker image issue where non-root
    # accounts have `cd` overriden by a function that has an unbound variable.
    # The unbound variable caues presubmit failure to due `set -u` above.
    # The `cd` override only happens for non-root users.
    builtin cd "$@"
  }

  # ANDROID_HOME is already in the environment.
  export ANDROID_NDK_HOME="/opt/android-ndk-r16b"

  # Create a tmpfs in the sandbox at "/tmp/hsperfdata_$USERNAME" to avoid the
  # problems described in https://github.com/bazelbuild/bazel/issues/3236
  # Basically, the JVM creates a file at /tmp/hsperfdata_$USERNAME/$PID, but
  # processes all get a PID of 2 in the sandbox, so concurrent Java build actions
  # could crash because they're trying to modify the same file. So, tell the
  # sandbox to mount a tmpfs at /tmp/hsperfdata_$(whoami) so that each JVM gets
  # its own version of that directory.
  hsperfdata_dir="/tmp/hsperfdata_$(whoami)_rules_android"
  mkdir "$hsperfdata_dir"

  COMMON_ARGS=(
    "--sandbox_tmpfs_path=$hsperfdata_dir"
    "--verbose_failures"
    "--experimental_google_legacy_api"
    "--experimental_enable_android_migration_apis"
    "--build_tests_only"
    # Java tests use language version at least 11, but they might depend on
    # libraries that were built for Java 17.
    "--java_language_version=11"
    "--java_runtime_version=17"
    "--test_output=errors"
  )

  # Go to rules_android workspace and run relevant tests.
  cd "${KOKORO_ARTIFACTS_DIR}/git/rules_android"

  # Fetch all external deps; should reveal any bugs related to external dep
  # references.
  "$bazel" aquery 'deps(...)' --noenable_bzlmod 2>&1 > /dev/null

  "$bazel" test "${COMMON_ARGS[@]}" //src/common/golang/... \
    //src/tools/ak/... \
    //src/tools/javatests/... \
    //src/tools/jdeps/... \
    //src/tools/java/... \
    //test/...

  # Go to basic app workspace in the source tree
  cd "${KOKORO_ARTIFACTS_DIR}/git/rules_android/examples/basicapp"
  "$bazel" build "${COMMON_ARGS[@]}" //java/com/basicapp:basic_app
}

main