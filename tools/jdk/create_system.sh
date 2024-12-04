#!/bin/bash
# Copyright 2024 The Bazel Authors. All rights reserved.
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

set -euo pipefail

function ParseArgs() {
  local args_original="$@"
  while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == "--input" ]]; then
      FLAGS_input="$2"
      shift
    elif [[ "$1" =~ "--input=" ]]; then
      FLAGS_input=$(echo $1 | cut -d= -f2)
    elif [[ "$1" == "--output" ]]; then
      FLAGS_output="$2"
      shift
    elif [[ "$1" =~ "--output=" ]]; then
      FLAGS_output=$(echo $1 | cut -d= -f2)
    elif [[ "$1" == "--unzip" ]]; then
      FLAGS_unzip="$2"
      shift
    elif [[ "$1" =~ "--unzip=" ]]; then
      FLAGS_unzip=$(echo $1 | cut -d= -f2)
    elif [[ "$1" == "--java_home" ]]; then
      FLAGS_java_home="$2"
      shift
    elif [[ "$1" =~ "--java_home=" ]]; then
      FLAGS_java_home=$(echo $1 | cut -d= -f2)
    elif [[ "$1" == "--module_info" ]]; then
      FLAGS_module_info="$2"
      shift
    elif [[ "$1" =~ "--module_info=" ]]; then
      FLAGS_module_info=$(echo $1 | cut -d= -f2)
    fi
    shift
  done
}

FLAGS_input=undefined
FLAGS_output=undefined
FLAGS_unzip=undefined
FLAGS_java_home=undefined
FLAGS_module_info=undefined
ParseArgs "$@"

DIR="$(mktemp -d)"

mkdir -p "${DIR}/jmod" "${DIR}/classes"

"${FLAGS_unzip}" -o -q -d "${DIR}/classes" "${FLAGS_input}"
chmod -R a+rx "${DIR}/classes"

rm -rf "${FLAGS_output}"

"${FLAGS_java_home}/bin/javac" \
  -d "${DIR}/classes" \
  --system=none \
  --patch-module=java.base="${DIR}/classes" \
  "${FLAGS_module_info}"

"${FLAGS_java_home}/bin/jmod" \
  create \
  --module-version "$("${FLAGS_java_home}/bin/jlink" --version)" \
  --target-platform linux-amd64 \
  --class-path "${DIR}/classes" \
  "${DIR}/jmod/java.base.jmod"

"${FLAGS_java_home}/bin/jlink" \
  --module-path "${DIR}/jmod" \
  --add-modules java.base \
  --output "${FLAGS_output}" \
  --disable-plugin system-modules \
  --disable-plugin generate-jli-classes

cp "${FLAGS_java_home}/lib/jrt-fs.jar" "${FLAGS_output}/lib/"
