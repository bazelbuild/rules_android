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
"""Starlark rules to include sdk toolchain into dep graph without actually utilize it."""

load("//providers:providers.bzl", "AndroidSdkInfo")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

def _dummy_toolchain_dep(_ctx):
    return [DefaultInfo()]

# This is a workaround for b/134583710
# Allows android rules to depend directly on a specific toolchain without extracting any details of
# the toolchain. This works around a dependency service bug: depending on the android toolchain only
# via Bazel's toolchain mechanisms would result in changes to these toolchains not flagging the
# android targets as affected targets. By adding this implicit indirect dependency, this service
# continues to correctly identify affected targets.
dummy_toolchain_dep = rule(
    implementation = _dummy_toolchain_dep,
    attrs = {
        "sdk_toolchain": attr.label(
            mandatory = True,
            providers = [AndroidSdkInfo],
        ),
    },
)
