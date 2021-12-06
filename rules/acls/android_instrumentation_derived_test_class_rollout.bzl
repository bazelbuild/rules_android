# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Rollout list for enabling test class derivation in android_instrumentation_test,"""

load("@rules_android//rules:acls.bzl", "make_dict", "matches")

_ANDROID_INSTRUMENTATION_TEST_DERIVED_TEST_CLASS_ROLLOUT = [
    "//:__subpackages__",
]

_ANDROID_INSTRUMENTATION_TEST_DERIVED_TEST_CLASS_FALLBACK = [
    "//javatests/notinacl:__subpackages__",
]

_ANDROID_INSTRUMENTATION_TEST_DERIVED_TEST_CLASS_ROLLOUT_DICT = make_dict(_ANDROID_INSTRUMENTATION_TEST_DERIVED_TEST_CLASS_ROLLOUT)
_ANDROID_INSTRUMENTATION_TEST_DERIVED_TEST_CLASS_FALLBACK_DICT = make_dict(_ANDROID_INSTRUMENTATION_TEST_DERIVED_TEST_CLASS_FALLBACK)

def acls_in_android_instrumentation_test_derived_test_class_rollout(fqn):
    return not matches(fqn, _ANDROID_INSTRUMENTATION_TEST_DERIVED_TEST_CLASS_FALLBACK_DICT) and matches(fqn, _ANDROID_INSTRUMENTATION_TEST_DERIVED_TEST_CLASS_ROLLOUT_DICT)
