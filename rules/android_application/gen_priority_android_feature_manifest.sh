#!/usr/bin/env bash --posix
# Copyright 2021 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
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
aapt="${5}"
in_manifest="${6}" # Developer-provided manifest for the feature module
is_asset_pack="${7}"

aapt_cmd="$aapt dump xmltree $base_apk --file AndroidManifest.xml"
version_code=$(${aapt_cmd} | grep "http://schemas.android.com/apk/res/android:versionCode" | cut -d "=" -f2 | head -n 1)
min_sdk=$(${aapt_cmd} | grep "http://schemas.android.com/apk/res/android:minSdkVersion" | cut -d "=" -f2 | head -n 1)
if [[ -z "$version_code" ]]
then
	echo "Base app missing versionCode in AndroidManifest.xml"
	exit 1
fi

if [[ -z "$min_sdk" ]]
then
	echo "Base app missing minsdk in AndroidManifest.xml"
	exit 1
fi

if [ "$is_asset_pack" = true ]
then
  # Note: tabs are required instead of spaces
  # https://stackoverflow.com/questions/18660798/here-document-gives-unexpected-end-of-file-error
	cat >$out_manifest <<-EOF
	<?xml version="1.0" encoding="utf-8"?>
	<manifest xmlns:android="http://schemas.android.com/apk/res/android"
			xmlns:dist="http://schemas.android.com/apk/distribution"
			package="$package"
			split="$split">
	</manifest>
	EOF
else
	cat >$out_manifest <<-EOF
	<?xml version="1.0" encoding="utf-8"?>
	<manifest xmlns:android="http://schemas.android.com/apk/res/android"
			xmlns:dist="http://schemas.android.com/apk/distribution"
			package="$package"
			split="$split"
			android:versionCode="$version_code"
			android:isFeatureSplit="true">

		<application android:hasCode="false" /> <!-- currently only supports asset splits -->
		<uses-sdk android:minSdkVersion="$min_sdk" />
	</manifest>
	EOF
fi
