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
"""Bazel rule for Android local test."""

load("//rules:android_host_hybrid_mode_transition.bzl", "android_host_hybrid_mode_transition")
load("//rules:utils.bzl", "ANDROID_SDK_TOOLCHAIN_TYPE")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(":attrs.bzl", "ATTRS")
load(":impl.bzl", "impl")

visibility(PROJECT_VISIBILITY)

_DEFAULT_CFG = android_host_hybrid_mode_transition

def make_rule(
        attrs = ATTRS,
        implementation = impl,
        additional_toolchains = [],
        cfg = _DEFAULT_CFG):
    """Makes the rule.

    Args:
      attrs: A dict. The attributes for the rule.
      implementation: A function. The rule's implementation method.
      additional_toolchains: A list of toolchain types to for the rule to use.
      cfg: The set of transitions to use on the incoming edge of the rule.

    Returns:
      A rule.
    """
    return rule(
        attrs = attrs,
        implementation = implementation,
        cfg = cfg,
        fragments = [
            "android",
            "bazel_android",  # NOTE: Only exists for Bazel
            "java",
        ],
        test = True,
        outputs = dict(
            deploy_jar = "%{name}_deploy.jar",
            jar = "%{name}.jar",
        ),
        toolchains = [
            "//toolchains/android:toolchain_type",
            ANDROID_SDK_TOOLCHAIN_TYPE,
            "@bazel_tools//tools/jdk:toolchain_type",
        ] + additional_toolchains,
        provides = [JavaInfo],
    )

android_local_test = make_rule()
