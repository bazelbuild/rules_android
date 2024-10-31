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
base_jar="${2}"
feature_jar="${3}"
filter_regex="${4:-""}"
tmp="$(mktemp -t featureXXXXXX).jar"

tmp_dir=$(mktemp -d)

# Compute the list of files to keep in the feature jar.
base_jar_lines=$(zip -sf "${base_jar}" | wc -l)
feature_jar_lines=$(zip -sf "${feature_jar}" | wc -l)

zip -sf "${base_jar}" | awk -v NR_last="${base_jar_lines}" -v filter="${filter_regex}" 'NR>1 && NR<(NR_last) && $1 !~ /\/$/ && $1 ~ filter {print $1}' | sort >> "${tmp_dir}/base_files" &
zip -sf "${feature_jar}" | awk -v NR_last="${feature_jar_lines}" 'NR>1 && NR<(NR_last) && $1 !~ /\/$/ {print $1}' | sort >> "${tmp_dir}/feature_files" &
wait
comm -23 "${tmp_dir}/feature_files" "${tmp_dir}/base_files" >> "${tmp_dir}/files_to_keep"

content_tmp_dir=$(mktemp -d)
if [[ ! -s "${tmp_dir}/files_to_keep" ]]; then
    touch "${content_tmp_dir}/.empty"
    (cd "${content_tmp_dir}" && zip -q "${tmp}" .empty && zip -q -d "${tmp}" .empty)
else
    abs_feature_jar="$(cd "$(dirname "${feature_jar}")" && pwd)/$(basename "${feature_jar}")"
    (cd "${content_tmp_dir}" && unzip -q "${abs_feature_jar}" $(cat "${tmp_dir}/files_to_keep" | tr '\n' ' '))
    (cd "${content_tmp_dir}" && zip -q -r "${tmp}" . )
fi

cp ${tmp} ${out}
