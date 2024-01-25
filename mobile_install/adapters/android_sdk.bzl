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
"""Rule adapter for android_sdk."""

load("//mobile_install:providers.bzl", "MIAndroidSdkInfo")
load(":base.bzl", "make_adapter")

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return ["aidl_lib"]

def _adapt(_, ctx):
    """Adapts the rule and target data.

    Args:
      _: The target.
      ctx: The context.

    Returns:
      A list of providers.
    """
    return [
        MIAndroidSdkInfo(
            aidl_lib = ctx.rule.attr.aidl_lib,
        ),
    ]

android_sdk = make_adapter(_aspect_attrs, _adapt)
