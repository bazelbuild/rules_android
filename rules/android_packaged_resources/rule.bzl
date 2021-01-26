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

"""Starlark Resource Packaging for Android Rules."""

load(":attrs.bzl", "ATTRS")
load(":impl.bzl", "impl")
load(
    "@rules_android//rules:attrs.bzl",
    _attrs = "attrs",
)

_DEFAULT_ALLOWED_ATTRS = ["name", "visibility", "tags", "testonly", "transitive_configs", "$enable_manifest_merging"]

_DEFAULT_PROVIDES = [AndroidApplicationResourceInfo, OutputGroupInfo]

# TODO(b/167721629): Rename android_packaged_resources to android_binary_internal.
def make_rule(
        attrs = ATTRS,
        implementation = impl,
        provides = _DEFAULT_PROVIDES):
    """Makes the rule.

    Args:
      attrs: A dict. The attributes for the rule.
      implementation: A function. The rule's implementation method.
      provides: A list. The providers that the rule must provide.

    Returns:
      A rule.
    """
    return rule(
        attrs = attrs,
        implementation = implementation,
        provides = provides,
        toolchains = ["@rules_android//toolchains/android:toolchain_type"],
        _skylark_testable = True,
        fragments = [
            "android",
            "java",
        ],
    )

_android_packaged_resources = make_rule()

def sanitize_attrs(attrs, allowed_attrs = ATTRS.keys()):
    """Sanitizes the attributes.

    The android_packaged_resources has a subset of the android_binary attributes, but is
    called from the android_binary macro with the same full set of attributes. This removes
    any unnecessary attributes.

    Args:
      attrs: A dict. The attributes for the android_packaged_resources rule.
      allowed_attrs: The list of attribute keys to keep.

    Returns:
      A dictionary containing valid attributes.
    """
    for attr_name in attrs.keys():
        if attr_name not in allowed_attrs and attr_name not in _DEFAULT_ALLOWED_ATTRS:
            attrs.pop(attr_name, None)

        # Some teams set this to a boolean/None which works for the native attribute but breaks
        # the Starlark attribute.
        if attr_name == "shrink_resources":
            if attrs[attr_name] == None:
                attrs.pop(attr_name, None)
            else:
                attrs[attr_name] = _attrs.tristate.normalize(attrs[attr_name])

    return attrs

def android_packaged_resources_macro(**attrs):
    """android_packaged_resources rule.

    Args:
      **attrs: Rule attributes
    """
    _android_packaged_resources(**sanitize_attrs(attrs))
