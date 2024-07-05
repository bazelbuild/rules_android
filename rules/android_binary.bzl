# Copyright 2019 The Bazel Authors. All rights reserved.
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
"""Bazel rule for building an APK."""

load("//rules:providers.bzl", "ApkInfo")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(
    "//rules/android_binary_internal:rule.bzl",
    "android_binary_internal_macro",
    "make_rule",
)

visibility(PROJECT_VISIBILITY)

_DEFAULT_PROVIDES = [ApkInfo, JavaInfo]

# TODO(b/329267394): Merge this rule with android_binary_internal after starlark migration is complete.
# This is a temporary workaround to rename the android_binary_internal rule to android_binary for
# rolling out the starlark migration. After it's rolled out, we can remove the deprecated
# android_binary_internal rule entirely.
android_binary = make_rule(provides = _DEFAULT_PROVIDES)

def android_binary_macro(**attrs):
    """Bazel android_binary rule.

    https://docs.bazel.build/versions/master/be/android.html#android_binary

    Args:
      **attrs: Rule attributes
    """

    android_binary_internal_macro(
        internal_rule = android_binary,
        **attrs
    )
