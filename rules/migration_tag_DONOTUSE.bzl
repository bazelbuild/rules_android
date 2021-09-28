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

"""Bazel component for the Android Skylark Migration."""

_MIGRATION_TAG = "__ANDROID_RULES_MIGRATION__"
_TAG_ATTR = "tags"

def add_migration_tag(attrs):
    if _TAG_ATTR in attrs and attrs[_TAG_ATTR] != None:
        attrs[_TAG_ATTR] = attrs[_TAG_ATTR] + [_MIGRATION_TAG]
    else:
        attrs[_TAG_ATTR] = [_MIGRATION_TAG]
    return attrs
