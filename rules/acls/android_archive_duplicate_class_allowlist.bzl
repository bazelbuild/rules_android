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

"""Allowlist for android_archive targets to skip duplicate class validation."""

# Map of {"//some:target": ["list.class", "of.class", "classes.class"]} which will be excluded from
# duplicate class validation.
# keep sorted
ANDROID_ARCHIVE_DUPLICATE_CLASS_ALLOWLIST = {
}
