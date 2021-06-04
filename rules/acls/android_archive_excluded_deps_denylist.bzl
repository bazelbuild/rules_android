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

"""Denylist for rules that are not allowed in android_archive excluded_deps."""

# keep sorted
ANDROID_ARCHIVE_EXCLUDED_DEPS_DENYLIST = [
    # Failure test support.
    "@rules_android//test/rules/android_archive/java/com/testdata/denied:__pkg__",
]
