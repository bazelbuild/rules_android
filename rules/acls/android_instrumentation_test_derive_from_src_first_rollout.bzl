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
"""Rollout and fallback list for deriving test classes from sources first in Android test macros."""

load("//rules:acls.bzl", "make_dict", "matches")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

_ANDROID_INSTRUMENTATION_TEST_DERIVE_FROM_SRC_FIRST_ROLLOUT = [
    "//:__subpackages__",
]

_ANDROID_INSTRUMENTATION_TEST_DERIVE_FROM_SRC_FIRST_FALLBACK = [
    "//javatests/notinacl:__subpackages__",
]

_ANDROID_INSTRUMENTATION_TEST_DERIVE_FROM_SRC_FIRST_ROLLOUT_DICT = make_dict(_ANDROID_INSTRUMENTATION_TEST_DERIVE_FROM_SRC_FIRST_ROLLOUT)
_ANDROID_INSTRUMENTATION_TEST_DERIVE_FROM_SRC_FIRST_FALLBACK_DICT = make_dict(_ANDROID_INSTRUMENTATION_TEST_DERIVE_FROM_SRC_FIRST_FALLBACK)

def acls_in_android_instrumentation_test_derive_from_src_first_rollout(fqn):
    return not matches(fqn, _ANDROID_INSTRUMENTATION_TEST_DERIVE_FROM_SRC_FIRST_FALLBACK_DICT) and matches(fqn, _ANDROID_INSTRUMENTATION_TEST_DERIVE_FROM_SRC_FIRST_ROLLOUT_DICT)
