#!/bin/bash --posix
# Copyright 2021 The Bazel Authors. All rights reserved.
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

out_manifest="${1}"
base_apk="${2}"
package="${3}"
split="${4}"
title_id="${5}"
fused="${6}"
aapt="${7}"

aapt_cmd="$aapt dump xmltree $base_apk --file AndroidManifest.xml"
version_code=$(${aapt_cmd} | grep "http://schemas.android.com/apk/res/android:versionCode" | cut -d "=" -f2 | head -n 1 )
if [[ -z "$version_code" ]]
then
  echo "Base app missing versionCode in AndroidManifest.xml"
  exit 1
fi

cat >$out_manifest <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:dist="http://schemas.android.com/apk/distribution"
    package="$package"
    split="$split"
    android:versionCode="$version_code"
    android:isFeatureSplit="true">

  <dist:module
      dist:instant="false"
      dist:title="@string/$title_id"> <!-- title must be an ID! Needs to work with proguard/resource shrinking -->
    <dist:fusing dist:include="$fused" />
    <dist:delivery>
      <dist:on-demand /></dist:delivery>
  </dist:module>

  <application android:hasCode="false" /> <!-- currently only supports asset splits -->
</manifest>
EOF
