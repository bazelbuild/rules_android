# Copyright 2020 The Bazel Authors. All rights reserved.
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
"""Allowlist of macro and targets that are allowed to use android_test."""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)
ANDROID_TEST_LOCKDOWN_GENERATOR_FUNCTIONS = [
]

ANDROID_TEST_LOCKDOWN_TARGETS = [
]
