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

load(":attrs.bzl", "ATTRS")
load(":impl.bzl", "impl")

def make_rule(
        attrs = ATTRS,
        implementation = impl):
    """Makes the rule.

    Args:
      attrs: A dict. The attributes for the rule.
      implementation: A function. The rule's implementation method.

    Returns:
      A rule.
    """
    return rule(
        attrs = attrs,
        implementation = implementation,
        cfg = config_common.config_feature_flag_transition("feature_flags"),
        fragments = [
            "android",
            "java",
        ],
        test = True,
        outputs = dict(
            deploy_jar = "%{name}_deploy.jar",
            jar = "%{name}.jar",
        ),
        toolchains = [
            "//toolchains/android:toolchain_type",
            "//toolchains/android_sdk:toolchain_type",
            "@bazel_tools//tools/jdk:toolchain_type",
        ],
    )

android_local_test = make_rule()
