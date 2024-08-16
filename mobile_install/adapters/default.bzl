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
"""Rule adapter for unknown rules without specific adapters"""

load(
    "//mobile_install:providers.bzl",
    "MIAndroidDexInfo",
    "MIJavaResourcesInfo",
    "providers",
)
load("//mobile_install:transform.bzl", "dex", "extract_jar_resources")
load("//mobile_install:utils.bzl", "utils")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(":base.bzl", "make_adapter")

visibility(PROJECT_VISIBILITY)

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return [
        "deps",
        "exports",
        "runtime_deps",
    ]

def _adapt(target, ctx):
    """The default adapter that will adapts custom rules.

    This adapter ensures we at least dex anything with a JavaInfo provider. If a rule needs more
    complex processing then a custom adapter should be created.

    Args:
      target: The target.
      ctx: The context.

    Returns:
      A list of providers.
    """
    if getattr(ctx.rule.attr, "neverlink", False):
        return []

    if not JavaInfo in target:
        return []

    return [
        providers.make_mi_android_dex_info(
            dex_shards = dex(
                ctx,
                target[JavaInfo].runtime_output_jars,
                target[JavaInfo].transitive_compile_time_jars,
                create_file = utils.declare_file,
            ),
            deps = providers.collect(
                MIAndroidDexInfo,
                getattr(ctx.rule.attr, "deps", []),
                getattr(ctx.rule.attr, "exports", []),
                getattr(ctx.rule.attr, "runtime_deps", []),
            ),
        ),
        providers.make_mi_java_resources_info(
            java_resources = extract_jar_resources(
                ctx,
                target[JavaInfo].runtime_output_jars,
                create_file = utils.declare_file,
            ),
            deps = providers.collect(
                MIJavaResourcesInfo,
                getattr(ctx.rule.attr, "deps", []),
                getattr(ctx.rule.attr, "exports", []),
                getattr(ctx.rule.attr, "runtime_deps", []),
            ),
        ),
    ]

default_adapter = make_adapter(_aspect_attrs, _adapt)
