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

"""Aspect to validate the transitive dependencies of an android_feature_module."""
_SRCS_DISALLOWED_EXTENSIONS = ["java", "kt", "srcjar"]

_DISALLOWED_RULE_TYPES = ["java_import", "aar_import"]

def _has_disallowed_srcs(srcs):
    if not srcs:
        return False
    for src in srcs:
        if src.extension in _SRCS_DISALLOWED_EXTENSIONS:
            return True
    return False

def _impl(target, ctx):
    if ctx.rule.kind in _DISALLOWED_RULE_TYPES:
        fail("android_feature_module cannot transitively depend on {} rules".format(ctx.rule.kind))
    srcs = getattr(ctx.rule.files, "srcs", [])
    if _has_disallowed_srcs(srcs):
        fail("android_feature_module cannot transitively depend on Java/Kotlin sources and {} has Java/Kotlin sources".format(target.label))
    if getattr(ctx.rule.attr, "resource_files", False):
        fail("android_feature_module cannot transitively depend on resource_files and {} has resource_files".format(target.label))
    return []

android_feature_module_validation_aspect = aspect(
    implementation = _impl,
    attr_aspects = ["deps", "exports"],
    doc = "An aspect that validates the dependencies of an android_feature_module.",
)
