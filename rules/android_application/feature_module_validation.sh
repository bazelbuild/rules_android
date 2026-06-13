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
lib_label="${4}"
xmllint="${5}"
unzip="${6}"
is_asset_pack="${7}"

if [[ -n "$manifest" ]]; then
  module_title=$("$xmllint" --xpath "string(//manifest/*[local-name()='module'][1]/@*[local-name()='title'])" "$manifest")

  if [[ "$is_asset_pack" = false && "$module_title" != "\${MODULE_TITLE}" ]]; then
    echo ""
    echo "$manifest dist:title should be \${MODULE_TITLE} placeholder. Found $module_title"
    echo ""
  fi
fi

touch "$out"
