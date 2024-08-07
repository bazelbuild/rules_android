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
"""Starlark Android Binary for Android Rules."""

load("//rules:acls.bzl", "acls")
load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)
load("//rules:utils.bzl", "ANDROID_SDK_TOOLCHAIN_TYPE")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":attrs.bzl", "ATTRS")
load(":impl.bzl", "impl")

visibility(PROJECT_VISIBILITY)

_DEFAULT_ALLOWED_ATTRS = ["name", "visibility", "tags", "testonly", "transitive_configs", "$enable_manifest_merging", "features", "exec_properties"]

_DEFAULT_PROVIDES = [ApkInfo, JavaInfo]

def _outputs(name, proguard_generate_mapping, _package_name, _generate_proguard_outputs):
    label = "//" + _package_name + ":" + name

    outputs = dict(
        deploy_jar = "%{name}_deploy.jar",
        unsigned_apk = "%{name}_unsigned.apk",
        signed_apk = "%{name}.apk",
    )

    # proguard_specs is too valuable an attribute to make it nonconfigurable, so if its value is
    # configurable (i.e. of type 'select'), _generate_proguard_outputs will be set to True and the
    # predeclared proguard outputs will be generated. If the proguard_specs attribute resolves to an
    # empty list eventually, we do not use it in the dexing. If user explicitly tries to request it,
    # it will fail.
    if not acls.use_r8(label) and _generate_proguard_outputs:
        outputs["proguard_jar"] = "%{name}_proguard.jar"
        outputs["proguard_config"] = "%{name}_proguard.config"
        if proguard_generate_mapping:
            outputs["proguard_map"] = "%{name}_proguard.map"
    return outputs

def make_rule(
        attrs = ATTRS,
        implementation = impl,
        provides = _DEFAULT_PROVIDES,
        outputs = _outputs,
        additional_toolchains = []):
    """Makes the rule.

    Args:
      attrs: A dict. The attributes for the rule.
      implementation: A function. The rule's implementation method.
      provides: A list. The providers that the rule must provide.
      outputs: A function. The rule's outputs method for declaring predeclared outputs.
      additional_toolchains: A list. Additional toolchains passed to pass to rule(toolchains).
    Returns:
      A rule.
    """
    return rule(
        attrs = attrs,
        implementation = implementation,
        provides = provides,
        toolchains = [
            "//toolchains/android:toolchain_type",
            ANDROID_SDK_TOOLCHAIN_TYPE,
            "@bazel_tools//tools/jdk:toolchain_type",
        ] + additional_toolchains,
        _skylark_testable = True,
        fragments = [
            "android",
            "bazel_android",  # NOTE: Only exists for Bazel
            "java",
            "cpp",
        ],
        outputs = outputs,
        cfg = config_common.config_feature_flag_transition("feature_flags"),
    )

android_binary = make_rule()

# TODO(zhaoqxu): Consider removing this method
def sanitize_attrs(attrs, allowed_attrs = ATTRS.keys()):
    """Sanitizes the attributes.

    Args:
      attrs: A dict. The attributes for the android_binary rule.
      allowed_attrs: The list of attribute keys to keep.

    Returns:
      A dictionary containing valid attributes.
    """
    for attr_name in list(attrs.keys()):
        if attr_name not in allowed_attrs and attr_name not in _DEFAULT_ALLOWED_ATTRS:
            attrs.pop(attr_name, None)
        elif attr_name == "shrink_resources":
            if attrs[attr_name] == None:
                attrs.pop(attr_name, None)
            else:
                # Some teams set this to a boolean/None which works for the native attribute but breaks
                # the Starlark attribute.
                attrs[attr_name] = _attrs.tristate.normalize(attrs[attr_name])

    return attrs

def android_binary_macro(**attrs):
    """android_binary rule.

    Args:
      **attrs: Rule attributes
    """

    # Required for ACLs check in _outputs(), since the callback can't access the native module.
    attrs["$package_name"] = native.package_name()

    if type(attrs.get("proguard_specs", None)) == "select" or attrs.get("proguard_specs", None):
        attrs["$generate_proguard_outputs"] = True

    android_binary(
        **sanitize_attrs(
            attrs,
            # _package_name and other attributes are allowed attributes but are also private.
            # We need to allow the $ form of the attribute to stop the sanitize function from
            # removing it.
            allowed_attrs = list(ATTRS.keys()) +
                            [
                                "$package_name",
                                "$rewrite_resources_through_optimizer",
                                "$generate_proguard_outputs",
                            ],
        )
    )
