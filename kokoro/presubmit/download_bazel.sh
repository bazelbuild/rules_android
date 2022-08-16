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


function DownloadBazel()  {
  # Utility function to download a specified version of bazel to a given
  # installation directory.
  # Positional arguments:
  #   ver: The version to install. Supports "latest" (major and minor releases),
  #     "latest-with-prereleases" (all versions from "latest" + prereleases),
  #     major/minor releases such as 5.2.0, and also prereleases such as
  #     6.0.0-pre.20220720.3. Release candidates with "rc" in the name are NOT
  #     supported.
  #   platform: The platform to install. Currently only "linux" has been
  #     validated.
  #   arch: Architecture to install. Currently only "x86_64" has been validated.
  #   dest: Where to install Bazel. Must be a user-writeable directory,
  #     otherwise the root user must call this function through sudo.
  # Returns:
  #   Echoes the installation directory at the end of installation.
  (
    set -euxo pipefail
    # Significantly cribbed from
    # devtools/kokoro/vanadium/linux_scripts/usr/local/bin/use_bazel.sh
    # Temporary workaround solution until use_bazel.sh can download prereleases.

    # Positional arguments
    local ver="$1"
    local platform="$2"
    local arch="$3"
    local dest="$4"

    # Function-local helper variables
    local gcs_uri=""
    local revision_identifier=""
    if [[ "$ver" == "latest" || "$ver" == "latest-with-prereleases" ]]; then
      # Query binary blob bucket to find the latest prerelease
      if [[ "$ver" == "latest" ]]; then
        # Filter out prereleases
        ver=$(gsutil ls -l gs://bazel/**/*-installer-"${platform}"-"${arch}".sh | grep "gs://" | grep -v rc | grep -v pre | tail -n1 | awk '{print $NF}')
      else
        ver=$(gsutil ls -l gs://bazel/**/*-installer-"${platform}"-"${arch}".sh | grep "gs://" | grep -v rc | tail -n1 | awk '{print $NF}')
      fi
      ver=$(echo "$ver" | sed -n "s/.*bazel\-\(.*\)\-installer.*/\1/p")
    fi
    if [[ "$ver" =~ pre ]]; then
      revision_identifier=$(echo "$ver" | awk -F"-" '{print $1}')
      gcs_uri="gs://bazel/${revision_identifier}/rolling/${ver}/bazel-${ver}-installer-${platform}-${arch}.sh"
    else
      gcs_uri="gs://bazel/${ver}/release/bazel-${ver}-installer-${platform}-${arch}.sh"
    fi

    # Download the installer from GCS
    gsutil -q cp "$gcs_uri" "$dest"/bazel_installer.sh
    mkdir -p "$dest"/install
    # Run the installer
    bash "$dest"/bazel_installer.sh --prefix="$dest"/install > /dev/null
    ls -d "$dest"/install
  )
}


