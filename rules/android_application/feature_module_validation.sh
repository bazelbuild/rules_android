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

out="${1}"
manifest="${2}"
apk="${3}"
is_coverage="${4}"
is_java8="${5}"
lib_label="${6}"
xmllint="${7}"
unzip="${8}"

if [[ -n "$manifest" ]]; then
  node_count=$("$xmllint" --xpath "count(//manifest/*)" "$manifest")
  module_count=$("$xmllint" --xpath "count(//manifest/*[local-name()='module'])" "$manifest")
  application_count=$("$xmllint" --xpath "count(//manifest/*[local-name()='application'])" "$manifest")
  application_attr_count=$("$xmllint" --xpath "count(//manifest/application/@*)" "$manifest")
  application_content_count=$("$xmllint" --xpath "count(//manifest/application/*)" "$manifest")
  module_title=$("$xmllint" --xpath "string(//manifest/*[local-name()='module'][1]/@*[local-name()='title'])" "$manifest")
  valid=0

  # Valid manifest, containing a dist:module and an empty <application/>
  if [[ "$node_count" == "2" &&
  "$module_count" == "1" &&
  "$application_count" == "1" &&
  "$application_attr_count" == "0" &&
  "$application_content_count" == "0" ]]; then
    valid=1
  fi

  # Valid manifest, containing a dist:module
  if [[ "$node_count" == "1" && "$module_count" == "1" ]]; then
    valid=1
  fi

  if [[ "$valid" == "0" ]]; then
    echo ""
    echo "$manifest should only contain a single <dist:module /> element (and optional empty <application/>), nothing else"
    echo "Manifest contents: "
    cat "$manifest"
    exit 1
  fi

  if [[ "$module_title" != "\${MODULE_TITLE}" ]]; then
    echo ""
    echo "$manifest dist:title should be \${MODULE_TITLE} placeholder"
    echo ""
    exit 1
  fi
fi

# Skip dex validation when running under code coverage.
# When running under code coverage an additional dep is implicitly added to all
# binary targets, causing a validation failure.
if [[ "$is_coverage" == "false" ]]; then
  dexes=$("$unzip" -l "$apk" | grep ".dex" | wc -l)
  if [[ ("$is_java8" == "true" && "$dexes" -gt 1 ) || ( "$is_java8" == "false" && "$dexes" -gt 0)]]; then
    echo ""
    echo "android_feature_module does not support Java or Kotlin sources."
    echo "Check $lib_label for any srcs or deps."
    echo ""
    exit 1
  fi
fi

touch "$out"
