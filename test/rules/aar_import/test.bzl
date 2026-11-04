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
"""Tests for aar_import."""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//test/utils:lib.bzl", "analysistest", "asserts")

visibility(PROJECT_VISIBILITY)

def _count_min_sdk_bumps(env):
    return len([a for a in analysistest.target_actions(env) if a.mnemonic == "BumpMinSdkFloor"])

def _min_sdk_bumped_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, 1, _count_min_sdk_bumps(env))
    return analysistest.end(env)

min_sdk_bumped_test = analysistest.make(_min_sdk_bumped_test_impl)

def _min_sdk_bump_skipped_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.equals(env, 0, _count_min_sdk_bumps(env))
    return analysistest.end(env)

min_sdk_bump_skipped_test = analysistest.make(
    _min_sdk_bump_skipped_test_impl,
    config_settings = {
        str(Label("//rules/flags:aar_import_skip_min_sdk_bump")): True,
    },
)
