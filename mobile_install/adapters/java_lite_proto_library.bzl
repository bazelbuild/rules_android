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
"""Rule adapter for java_lite_proto_library.

The java_lite_proto_library rule applies an aspect onto its proto dependencies.
Creates a "lite.jar" at every proto traversed. This adapter is used to just
propagate the deps, the proto_library rules.
"""

load(":adapters/base.bzl", "make_adapter")
load(":providers.bzl", "MIAndroidDexInfo", "MIJavaResourcesInfo", "providers")

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return ["deps", "_aspect_proto_toolchain_for_javalite"]

def _adapt(target, ctx):
    """Adapts the rule and target data.

    Args:
      target: The target.
      ctx: The context.

    Returns:
      A list of providers.
    """
    if not ctx.rule.attr.deps:
        return []
    return [
        providers.make_mi_android_dex_info(
            deps = providers.collect(
                MIAndroidDexInfo,
                ctx.rule.attr.deps,
                [ctx.rule.attr._aspect_proto_toolchain_for_javalite],
            ),
        ),
        providers.make_mi_java_resources_info(
            deps = providers.collect(
                MIJavaResourcesInfo,
                ctx.rule.attr.deps,
                [ctx.rule.attr._aspect_proto_toolchain_for_javalite],
            ),
        ),
    ]

java_lite_proto_library = make_adapter(_aspect_attrs, _adapt)
