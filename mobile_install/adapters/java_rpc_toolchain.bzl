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
"""Rule adapter for java_rpc_toolchain.bzl."""

load("//mobile_install:providers.bzl", "MIAndroidDexInfo", "providers")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":base.bzl", "make_adapter")

visibility(PROJECT_VISIBILITY)

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return ["runtime"]  # all potential implicit runtime deps

def _adapt(_, ctx):
    """Adapts the rule and target data.

    Args:
      _: The target.
      ctx: The context.

    Returns:
      A list of providers.
    """
    return [
        providers.make_mi_android_dex_info(
            deps = providers.collect(MIAndroidDexInfo, ctx.rule.attr.runtime),
        ),
    ]

java_rpc_toolchain = make_adapter(_aspect_attrs, _adapt)
