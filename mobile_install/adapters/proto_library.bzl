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
"""Rule adapter for proto_library."""

load(":adapters/base.bzl", "make_adapter")
load(":providers.bzl", "MIAndroidDexInfo", "providers")
load(":transform.bzl", "dex")

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return ["deps"]

def _adapt(target, ctx):
    """Adapts the rule and target data.

    Args:
      target: The target.
      ctx: The context.

    Returns:
      A list of providers.
    """
    if not JavaInfo in target:
        return []
    return [
        providers.make_mi_android_dex_info(
            dex_shards = dex(
                ctx,
                [j.class_jar for j in target[JavaInfo].outputs.jars],
                target[JavaInfo].transitive_compile_time_jars,
            ),
            deps = providers.collect(MIAndroidDexInfo, ctx.rule.attr.deps),
        ),
    ]

proto_library = make_adapter(_aspect_attrs, _adapt)
