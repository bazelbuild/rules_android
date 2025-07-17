#!/bin/bash
# Copyright 2018 The Bazel Authors. All rights reserved.
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

set -eu

NATIVE_RES_APK=%native_apk%
V3_RES_APK=%v3_apk%
NATIVE_R_JAR=%native_r_jar%
V3_R_JAR=%v3_r_jar%
AAPT=%aapt%
VALIDATION_OUTPUT=%validation_output%

# Produce an output if this script will run as a validation action
if [[ $VALIDATION_OUTPUT != %*% ]]; then
  echo "Producing validation output"
  echo "" > $VALIDATION_OUTPUT
fi

# Validate the R.jar
if [[ -z $NATIVE_R_JAR && -z $V3_R_JAR ]];  then
  # Do nothing because both R.jar paths are empty.
  echo
elif [[ $NATIVE_R_JAR == %*% && $V3_R_JAR == %*% ]]; then
  # Do nothing because R.jar from either pipeline has not been specified.
  echo
else
  NATIVE_R_JAR_ENTRIES=`unzip -Z1 $NATIVE_R_JAR | grep -v "/$"`
  V3_R_JAR_ENTRIES=`unzip -Z1 $V3_R_JAR | grep -v "/$"`
  if [ "$NATIVE_R_JAR_ENTRIES" == "$V3_R_JAR_ENTRIES" ]; then
    echo "R Jar files match!"
  else
    echo "R Jar files DO NOT MATCH"
    echo "Native: $NATIVE_R_JAR"
    echo "V3: $V3_R_JAR"
    exit 1
  fi
fi

if [[ -z $NATIVE_RES_APK && -z $V3_RES_APK ]];  then
  exit
fi

echo "Native APK: $NATIVE_RES_APK"
echo "V3 APK: $V3_RES_APK"

# Validate manifests
NATIVE_MANIFEST=`$AAPT dump xmltree $NATIVE_RES_APK --file AndroidManifest.xml`
V3_MANIFEST=`$AAPT dump xmltree $V3_RES_APK --file AndroidManifest.xml`
if [ "$NATIVE_MANIFEST" == "$V3_MANIFEST" ]; then
  echo "Manifests match!"
else
  echo "Manifests DO NOT MATCH"
  echo "Native: $NATIVE_MANIFEST"
  echo "V3: $V3_MANIFEST"
  echo -e "\n\n\n"
  echo "Diff:"
  diff <(echo "$NATIVE_MANIFEST") <(echo "$V3_MANIFEST")
  exit 1
fi

# Validate resources
NATIVE_RES=`$AAPT dump resources -v $NATIVE_RES_APK`
V3_RES=`$AAPT dump resources -v $V3_RES_APK`
if [ "$NATIVE_RES" == "$V3_RES" ]; then
  echo "Resources match!"
else
  echo "Resources DO NOT MATCH"
  echo "Native: $NATIVE_RES"
  echo "V3: $V3_RES"
  echo -e "\n\n\n"
  echo "Diff:"
  diff <(echo "$NATIVE_RES") <(echo "$V3_RES")
  exit 1
fi

# Validate assets and other APK contents
# Ignore META-INF and dex files, which are present in final APKs, because the
# contents of these files can be impacted by the target name.
NATIVE_UNZIP=`unzip -v $NATIVE_RES_APK | head -n -1 | sed '1d' | grep -vE "META-INF|dex|.*\/$"`
V3_UNZIP=`unzip -v $V3_RES_APK | head -n -1 | sed '1d' | grep -vE "META-INF|dex|.*\/$"`

# Also remove directory entries because we add an additional directory layer
# to the artifact tree, which creates extra empty entries.
NATIVE_UNZIP=`echo "$NATIVE_UNZIP" | grep -v ".*\/$"`
V3_UNZIP=`echo "$V3_UNZIP" | grep -v ".*\/$"`

# Remove _NATIVE and _RESOURCES_DO_NOT_USE from path segments.
NATIVE_UNZIP=`echo "$NATIVE_UNZIP" | sed -re 's/(.*assets.*)(_NATIVE)(.*)/\1\3/'`
V3_UNZIP=`echo "$V3_UNZIP" | sed -re 's/(.*assets.*)(_RESOURCES_DO_NOT_USE)(.*)/\1\3/'`

# Remove _migrated from V3 path segments.
V3_UNZIP=`echo "$V3_UNZIP" | sed -re 's#(.*assets/.*)(\_migrated/)(.*)#\1\3#'`

# Sort since we changed path segments
NATIVE_UNZIP=`echo "$NATIVE_UNZIP" | sort`
V3_UNZIP=`echo "$V3_UNZIP" | sort`

if [[ "$NATIVE_UNZIP" == "$V3_UNZIP" ]]; then
  echo "APK contents match!"
else
  echo "APK contents DO NOT MATCH"
  echo "Native: $NATIVE_UNZIP"
  echo "V3: $V3_UNZIP"
  echo -e "\n\n\n"
  echo "Diff:"
  diff <(echo "$NATIVE_UNZIP") <(echo "$V3_UNZIP")
  exit 1
fi
