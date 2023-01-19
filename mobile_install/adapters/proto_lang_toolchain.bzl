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
"""Rule adapter for proto_lang_toolchain."""

load(":adapters/base.bzl", "make_adapter")
load(":providers.bzl", "MIAndroidDexInfo", "MIJavaResourcesInfo", "providers")

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return ["runtime"]

def _adapt(unused_target, ctx):
    """Adapts the rule and target data.

    Args:
      unused_target: The target.
      ctx: The context.

    Returns:
      A list of providers.
    """
    if not ctx.rule.attr.runtime:
        return []
    return [
        providers.make_mi_android_dex_info(
            deps = providers.collect(
                MIAndroidDexInfo,
                [ctx.rule.attr.runtime],
            ),
        ),
        providers.make_mi_java_resources_info(
            deps = providers.collect(
                MIJavaResourcesInfo,
                [ctx.rule.attr.runtime],
            ),
        ),
    ]

proto_lang_toolchain = make_adapter(_aspect_attrs, _adapt)
