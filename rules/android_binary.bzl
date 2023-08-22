# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Bazel rule for building an APK."""

load(":common.bzl", "common")
load(":migration_tag_DONOTUSE.bzl", "add_migration_tag")
load("//rules/android_binary_internal:rule.bzl", "android_binary_internal_macro")
load("//rules:acls.bzl", "acls")

def android_binary(**attrs):
    """Bazel android_binary rule.

    https://docs.bazel.build/versions/master/be/android.html#android_binary

    Args:
      **attrs: Rule attributes
    """
    android_binary_internal_name = ":" + attrs["name"] + common.PACKAGED_RESOURCES_SUFFIX
    android_binary_internal_macro(
        **dict(
            attrs,
            name = android_binary_internal_name[1:],
            visibility = ["//visibility:private"],
        )
    )

    attrs.pop("$enable_manifest_merging", None)

    # dex_shards is deprecated and unused. This only existed for mobile-install classic which has
    # been replaced by mobile-install v2
    attrs.pop("dex_shards", None)

    # resource_apks is not used by the native android_binary
    attrs.pop("resource_apks", None)

    fqn = "//%s:%s" % (native.package_name(), attrs["name"])
    if acls.use_r8(fqn):
        # Do not pass proguard specs to the native android_binary so that it does
        # not try to use proguard and instead uses the dex files from the
        # AndroidDexInfo provider from android_binary_internal.
        # This also disables resource shrinking from native android_binary (reguardless of the
        # shrink_resources attr).
        attrs["proguard_specs"] = []

    native.android_binary(
        application_resources = android_binary_internal_name,
        **add_migration_tag(attrs)
    )
