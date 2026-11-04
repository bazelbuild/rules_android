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

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo", "string_list_flag")

WrappedFlagsInfo = provider(
    doc = "Provides all flags",
    fields = dict(
        flags = "Map of flag name to BuildSettingInfo",
    ),
)

def _get_set_ctor():
    set_ctor = getattr(bazel_features.globals, "set", None)

    return set_ctor

_SET = _get_set_ctor()

HAS_STRING_SET = hasattr(config, "string_set") and _SET != None

def _string_set_flag_impl(ctx):
    return [BuildSettingInfo(value = ctx.build_setting_value)]

_string_set_flag = rule(
    implementation = _string_set_flag_impl,
    build_setting = config.string_set(flag = True),
    doc = "A string set build setting that can be set on the command line.",
) if HAS_STRING_SET else None

def android_platforms_flag(
        name,
        build_setting_default = None,
        has_string_set = HAS_STRING_SET,
        **kwargs):
    """Defines a build setting flag for --android_platforms.

    Uses config.string_set on Bazel 9+ (where config.string_set and Starlark
    sets are available) and falls back to string_list_flag on Bazel 7 and 8.

    Args:
      name: Name of the build setting target.
      build_setting_default: Optional default iterable of platform strings.
      has_string_set: Whether to use config.string_set (overridable in tests).
      **kwargs: Additional rule attributes (e.g. visibility).
    """
    default_items = build_setting_default or []
    if has_string_set and _string_set_flag != None:
        _string_set_flag(
            name = name,
            build_setting_default = _SET(default_items),
            **kwargs
        )
    else:
        string_list_flag(
            name = name,
            build_setting_default = list(default_items),
            **kwargs
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
        targets = attr.label_list(allow_files = True),
    ),
)

def flags_wrapper_macro(name = "flags_wrapper"):
    flags_wrapper(
        name = name,
        targets = native.existing_rules().keys(),
        visibility = ["//visibility:public"],
    )

testing = struct(
    set_ctor = _SET,
)
