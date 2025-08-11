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
"""Defines a split transition for to set both merge orders for the merge order test."""

load("//providers:providers.bzl", "ApkInfo")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

def _manifest_merge_split_transition_impl(_settings, _attr):
    return {
        "legacy": {"//rules/flags:manifest_merge_order": "legacy"},
        "dependency": {"//rules/flags:manifest_merge_order": "dependency"},
    }

_manifest_merge_split_transition = transition(
    implementation = _manifest_merge_split_transition_impl,
    inputs = [],
    outputs = ["//rules/flags:manifest_merge_order"],
)

def _manifest_merge_split_impl(ctx):
    dep_apk_link = ctx.actions.declare_file("app_dependency_order.apk")
    dep_apk = ctx.split_attr.binary["dependency"][ApkInfo].signed_apk
    ctx.actions.symlink(output = dep_apk_link, target_file = dep_apk)

    legacy_apk_link = ctx.actions.declare_file("app_legacy_order.apk")
    legacy_apk = ctx.split_attr.binary["legacy"][ApkInfo].signed_apk
    ctx.actions.symlink(output = legacy_apk_link, target_file = legacy_apk)

    return DefaultInfo(
        files = depset([dep_apk_link, legacy_apk_link]),
        runfiles = ctx.runfiles(files = [dep_apk_link, legacy_apk_link, dep_apk, legacy_apk]),
    )

manifest_merge_split = rule(
    implementation = _manifest_merge_split_impl,
    attrs = {
        "binary": attr.label(cfg = _manifest_merge_split_transition),
    },
)
