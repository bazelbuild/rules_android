# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Aspect to collect neverlink libraries in the transitive closure.

Used for determining the -libraryjars argument for Proguard. The compile-time classpath is
unsufficient here as those are ijars.
"""

load(
    "//rules:utils.bzl",
    "utils",
)

StarlarkAndroidNeverlinkInfo = provider(
    doc = "Contains all neverlink libraries in the transitive closure.",
    fields = {
        "transitive_neverlink_libraries": "Depset of transitive neverlink jars",
    },
)

_ATTRS = ["deps", "exports", "runtime_deps", "binary_under_test", "$instrumentation_test_runner"]

def _android_neverlink_aspect_impl(target, ctx):
    # Only run on Android targets
    if "android" not in getattr(ctx.rule.attr, "constraints", "") and not ctx.rule.kind.startswith("android_"):
        return []

    deps = []
    for attr in _ATTRS:
        if type(getattr(ctx.rule.attr, attr, None)) == "list":
            deps.extend(getattr(ctx.rule.attr, attr))

    direct_runtime_jars = depset(
        target[JavaInfo].runtime_output_jars,
        transitive = [target[AndroidLibraryResourceClassJarProvider].jars] if AndroidLibraryResourceClassJarProvider in target else [],
    )

    neverlink_libs = _collect_transitive_neverlink_libs(ctx, deps, direct_runtime_jars)

    return [StarlarkAndroidNeverlinkInfo(transitive_neverlink_libraries = neverlink_libs)]

def _collect_transitive_neverlink_libs(ctx, deps, runtime_jars):
    neverlink_runtime_jars = []
    for provider in utils.collect_providers(StarlarkAndroidNeverlinkInfo, deps):
        neverlink_runtime_jars.append(provider.transitive_neverlink_libraries)

    if getattr(ctx.rule.attr, "neverlink", False):
        neverlink_runtime_jars.append(runtime_jars)
        for java_info in utils.collect_providers(JavaInfo, deps):
            neverlink_runtime_jars.append(java_info.transitive_runtime_jars)

    return depset([], transitive = neverlink_runtime_jars)

android_neverlink_aspect = aspect(
    implementation = _android_neverlink_aspect_impl,
    attr_aspects = _ATTRS,
)
