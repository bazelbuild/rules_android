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

load("//rules:desugar.bzl", "desugar")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

visibility(PROJECT_VISIBILITY)

def get_desugar_classpath(ctx, java_info):
    return desugar.get_classpath(
        java_info,
        use_header_jars = ctx.attr._desugar_with_header_jars[BuildSettingInfo].value,
    )
