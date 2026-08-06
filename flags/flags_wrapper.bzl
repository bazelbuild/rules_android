# Copyright 2026 The Bazel Authors. All rights reserved.
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
"""Custom flags wrapper."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

WrappedFlagsInfo = provider(
    doc = "Provides all flags",
    fields = dict(
        flags = "Map of flag name to BuildSettingInfo",
    ),
)

def _flags_wrapper_impl(ctx):
    return [WrappedFlagsInfo(
        flags = {
            t.label.name: t[BuildSettingInfo]
            for t in ctx.attr.targets
            if BuildSettingInfo in t
        },
    )]

flags_wrapper = rule(
    implementation = _flags_wrapper_impl,
    attrs = dict(
        targets = attr.label_list(),
    ),
)

def flags_wrapper_macro(name = "flags_wrapper"):
    flags_wrapper(
        name = name,
        targets = native.existing_rules().keys(),
        visibility = ["//visibility:public"],
    )
