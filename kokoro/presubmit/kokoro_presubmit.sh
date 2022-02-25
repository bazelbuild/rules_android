#!/bin/bash
# Copyright 2022 The Bazel Authors. All rights reserved.
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

set -e
set -x

bazel="${KOKORO_GFILE_DIR}/bazel-${bazel_version}-linux-x86_64"
chmod +x "$bazel"

# Kokoro is no longer updating toolchains in their images, so install newer
# android build tools, because the latest one installed (26.0.2) has some bug
# in APPT2 which causes the magic number to be incorrect for some files it
# outputs.
#
# Use "yes" to accept sdk licenses.
cd "$ANDROID_HOME"
yes | tools/bin/sdkmanager --install "build-tools;30.0.3" &>/dev/null
yes | tools/bin/sdkmanager --licenses &>/dev/null

# ANDROID_HOME is already in the environment.
export ANDROID_NDK_HOME="/opt/android-ndk-r16b"

# Go to basic app workspace in the source tree
cd "${KOKORO_ARTIFACTS_DIR}/git/rules_android/examples/basicapp"

# Create a tmpfs in the sandbox at "/tmp/hsperfdata_$USERNAME" to avoid the
# problems described in https://github.com/bazelbuild/bazel/issues/3236
# Basically, the JVM creates a file at /tmp/hsperfdata_$USERNAME/$PID, but
# processes all get a PID of 2 in the sandbox, so concurrent Java build actions
# could crash because they're trying to modify the same file. So, tell the
# sandbox to mount a tmpfs at /tmp/hsperfdata_$(whoami) so that each JVM gets
# its own version of that directory.
hsperfdata_dir="/tmp/hsperfdata_$(whoami)_rules_android"
mkdir "$hsperfdata_dir"

"$bazel" build \
    --sandbox_tmpfs_path="$hsperfdata_dir" \
    --verbose_failures \
    --experimental_google_legacy_api \
    --experimental_enable_android_migration_apis \
    //java/com/basicapp:basic_app
