# Copyright 2025 The Bazel Authors. All rights reserved.
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
"""Shared logic related to desugaring. """

load("//rules:acls.bzl", "acls")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//rules/flags:flags.bzl", _flags = "flags")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

visibility(PROJECT_VISIBILITY)

_PRUNE_DESUGAR_DEPS_INCOMPATIBLE_TAG = "android_experimental_prune_desugar_deps_incompatible"

def _prune_desugar_classpath(ctx):
    """Reduced desugar classpath built from direct deps' compile_jars."""
    transitive = []
    for attr_name in ("deps", "exports"):
        for dep in getattr(ctx.rule.attr, attr_name, []) or []:
            if JavaInfo in dep:
                transitive.append(dep[JavaInfo].compile_jars)
    return depset(transitive = transitive)

def get_desugar_classpath(ctx, target):
    if (_flags.get(ctx).experimental_prune_desugar_classpath and
        _PRUNE_DESUGAR_DEPS_INCOMPATIBLE_TAG not in getattr(ctx.rule.attr, "tags", [])):
        return _prune_desugar_classpath(ctx)
    java_info = target[JavaInfo]
    if acls.in_desugaring_runtime_jar_classpath_rollout():
        return java_info._transitive_full_compile_time_jars
    return java_info.transitive_compile_time_jars
