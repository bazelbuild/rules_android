# Copyright 2023 The Bazel Authors. All rights reserved.
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
"""Provides access to the base set of rule adapters with a simple interface."""

load(":adapters/aar_import.bzl", "aar_import")
load(":adapters/android_binary.bzl", "android_binary")
load(":adapters/android_library.bzl", "android_library")
load(":adapters/android_sdk.bzl", "android_sdk")
load(":adapters/android_instrumentation_test.bzl", "android_instrumentation_test")
load(":adapters/apk_import.bzl", "apk_import")
load(":adapters/java_import.bzl", "java_import")
load(":adapters/java_library.bzl", "java_library")
load(":adapters/java_lite_proto_library.bzl", "java_lite_proto_library")
load(":adapters/proto_library.bzl", "proto_library")
load(":adapters/proto_lang_toolchain.bzl", "proto_lang_toolchain")

# Visible for testing
ADAPTERS = dict(
    aar_import = aar_import,
    android_binary = android_binary,
    android_library = android_library,
    android_sdk = android_sdk,
    android_instrumentation_test = android_instrumentation_test,
    apk_import = apk_import,
    java_import = java_import,
    java_library = java_library,
    java_lite_proto_library = java_lite_proto_library,
    proto_lang_toolchain = proto_lang_toolchain,
    proto_library = proto_library,
)

def get(kind, adapters = ADAPTERS):
    return adapters.get(kind, None)

def get_all_aspect_attrs(adapters = ADAPTERS):
    """The union of all the aspect attrs required by all rule adapters.

    The list is used by the aspect to determine the set of attributes to apply on.

    Args:
      adapters: The dict of adapters to process. Default value is the base adapter set.

    Returns:
      A sorted list of strings, containing the union of all attribute names
      required by the all the rule adapters.
    """
    attrs = {}
    for adapter in adapters.values():
        for attr in adapter.aspect_attrs():
            attrs[attr] = True
    return attrs.keys()
