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
""" Module for handling minSdkVersion configuration.

This module holds the current minimum minSdkVersion supported by the Android Rules. Additionally
it holds utilities for handling minSdkVersion propagation.

"""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

visibility(PROJECT_VISIBILITY)

_SETTING = "//rules/flags:min_sdk_version"
_DEPOT_FLOOR = 21
_MIN_SDK_LEVELS = sorted([_DEPOT_FLOOR, 24])

_ATTRS = dict(
    _min_sdk_version = attr.label(
        default = Label(_SETTING),
        providers = [BuildSettingInfo],
    ),
)

def _clamp(min_sdk_version):
    # TODO(asinclair): Uncomment this once android_binary is Starlarkified and the order of the
    # Android Platforms Transition and Feature Flags transition is swapped.
    # clamped = _MIN_SDK_LEVELS[0]
    # for m in _MIN_SDK_LEVELS:
    #     if m > min_sdk_version:
    #         return clamped
    #     clamped = m
    # return clamped
    return 0

def _get(ctx):
    # This is the case when an android_binary target does not set a value explicitly.
    # The configuration value defaults to 0
    # So in this case we use the depot floor.
    # TODO(asinclair): Uncomment this once android_binary is Starlarkified and the order of the
    # Android Platforms Transition and Feature Flags transition is swapped.
    # if not ctx.attr._min_sdk_version[BuildSettingInfo].value:
    #     return _DEPOT_FLOOR
    # return ctx.attr._min_sdk_version[BuildSettingInfo].value
    return 0

min_sdk_version = struct(
    attrs = _ATTRS,
    SETTING = _SETTING,
    clamp = _clamp,
    get = _get,
    DEPOT_FLOOR = _DEPOT_FLOOR,
)
