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

# Set up the SDK as root to avoid having to deal with user file permissions

# Kokoro is no longer updating toolchains in their images, so install newer
# android build tools, because the latest one installed (26.0.2) has some bug
# in APPT2 which causes the magic number to be incorrect for some files it
# outputs.
#
cd "$ANDROID_HOME"

# Use "yes" to accept sdk licenses.
yes | cmdline-tools/latest/bin/sdkmanager --install "build-tools;30.0.3" "extras;android;m2repository" &>/dev/null
yes | cmdline-tools/latest/bin/sdkmanager --licenses &>/dev/null
chmod -R o=rx "$ANDROID_HOME"

# Remainder of this file deals with setting up a non-root build account,
# and using it to run presubmit
# User account needs to be able to read $ANDROID_HOME (+r) and traverse directories (+x)
chmod -R o=rx "$ANDROID_HOME"

# Make the non-root account
export KOKORO_USER="bazel-builder"
useradd -m -s /bin/bash "$KOKORO_USER"

# Run presubmit as bazel-builder, and pass ANDROID_HOME and KOKORO_ARTIFACTS_DIR
# from root user's environment to bazel-builder's environment
runuser -w ANDROID_HOME,KOKORO_ARTIFACTS_DIR -l "$KOKORO_USER" \
  -c "bash ${KOKORO_ARTIFACTS_DIR}/git/rules_android/kokoro/presubmit/presubmit_main.sh"