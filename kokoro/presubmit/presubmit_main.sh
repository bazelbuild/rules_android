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

function DownloadBazelCI()  {
  # Utility function to download bazelci.py as a test runner.
  # Positional arguments:
  #   dest: Where to install bazelci.py. Must be a user-writeable directory,
  #     otherwise the root user must call this function through sudo.
  (
    set -euxo pipefail

    # Positional arguments
    local dest="${1:-${TMPDIR}/test_runner}"

    download_url="https://raw.githubusercontent.com/bazelbuild/continuous-integration/master/buildkite/bazelci.py"
    mkdir -p "${dest}"
    wget -nv ${download_url} -O "${dest}/bazelci.py"
    chmod +x "${dest}/bazelci.py"
    export PATH="${dest}:${PATH}"

    # Set up the bazelci environment.
    export BUILDKITE_ORGANIZATION_SLUG=bazel
    export BUILDKITE_COMMIT=HEAD
    export BUILDKITE_BRANCH=main
    export BAZELCI_LOCAL_RUN=true # Don't use remote caching or upload logs.

    echo "bazelci.py installation completed."
  )
}

function main() {
  set -euxo pipefail
  echo "== installing bazelci ========================================="
  test_runner_dir=$(mktemp -d)
  DownloadBazelCI "$test_runner_dir"
  bazelci="$test_runner_dir/bazelci.py"
  echo "============================================================="

  function Cleanup() {
    # Clean up all temporary directories.
    rm -rf "$test_runner_dir"
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

  # Go to rules_android workspace and run relevant tests.
  cd "${KOKORO_ARTIFACTS_DIR}/git/rules_android"

  TASKS=(
    ubuntu2004_rules
    ubuntu2004_tools
    ubuntu2004_rules_bzlmod
    ubuntu2004_tools_bzlmod
    basicapp
  )

  for task in "${TASKS[@]}"; do
    python "${test_runner_dir}/bazelci.py" \
        --file_config=.bazelci/presubmit.yml \
        --task="${task}"
  done
}

main
