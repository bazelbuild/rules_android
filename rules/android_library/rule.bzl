# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""android_library rule."""

load(":attrs.bzl", _ATTRS = "ATTRS")
load(":impl.bzl", _impl = "impl")
load(
    "@rules_android//rules:attrs.bzl",
    _attrs = "attrs",
)

def _outputs(_defined_local_resources):
    outputs = dict(
        lib_jar = "lib%{name}.jar",
        lib_src_jar = "lib%{name}-src.jar",
        aar = "%{name}.aar",
    )

    if _defined_local_resources:
        # TODO(b/177261846): resource-related predeclared outputs need to be re-pointed at the
        # corresponding artifacts in the Starlark pipeline.
        outputs.update(
            dict(
                resources_src_jar = "_migrated/%{name}.srcjar",
                resources_txt = "_migrated/%{name}_symbols/R.txt",
                resources_jar = "_migrated/%{name}_resources.jar",
            ),
        )

    return outputs

def make_rule(
        attrs = _ATTRS,
        implementation = _impl,
        outputs = _outputs,
        additional_toolchains = []):
    """Makes the rule.

    Args:
      attrs: A dict. The attributes for the rule.
      implementation: A function. The rule's implementation method.

    Returns:
      A rule.
    """
    return rule(
        attrs = attrs,
        fragments = [
            "android",
            "java",
        ],
        implementation = implementation,
        provides = [
            AndroidCcLinkParamsInfo,
            AndroidIdeInfo,
            AndroidIdlInfo,
            AndroidLibraryResourceClassJarProvider,
            AndroidNativeLibsInfo,
            JavaInfo,
        ],
        outputs = outputs,
        toolchains = [
            "@rules_android//toolchains/android:toolchain_type",
            "@rules_android//toolchains/android_sdk:toolchain_type",
        ] + additional_toolchains,
        _skylark_testable = True,
    )

android_library = make_rule()

def _is_defined(name, attrs):
    return name in attrs and attrs[name] != None

def attrs_metadata(attrs):
    """Adds additional metadata for specific android_library attrs.

    Bazel native rules have additional capabilities when inspecting attrs that
    are not available in Starlark. For example, native rules are able to
    determine if an attribute was set by a user and make decisions based on this
    knowledge - sometimes the behavior may differ if the user specifies the
    default value of the attribute. As such the Starlark android_library uses
    this shim to provide similar capabilities.

    Args:
      attrs: The attributes passed to the android_library rule.

    Returns:
      A dictionary containing attr values with additional metadata.
    """

    # Required for the outputs.
    attrs["$defined_local_resources"] = bool(
        attrs.get("assets") or
        attrs.get("assets_dir") or
        attrs.get("assets_dir") == "" or
        attrs.get("export_manifest") or
        attrs.get("manifest") or
        attrs.get("resource_files"),
    )

    # TODO(b/116691720): Remove normalization when bug is fixed.
    if _is_defined("exports_manifest", attrs):
        attrs["exports_manifest"] = _attrs.tristate.normalize(
            attrs.get("exports_manifest"),
        )

    # TODO(b/127517031): Remove these entries once fixed.
    attrs["$defined_assets"] = _is_defined("assets", attrs)
    attrs["$defined_assets_dir"] = _is_defined("assets_dir", attrs)
    attrs["$defined_idl_import_root"] = _is_defined("idl_import_root", attrs)
    attrs["$defined_idl_parcelables"] = _is_defined("idl_parcelables", attrs)
    attrs["$defined_idl_srcs"] = _is_defined("idl_srcs", attrs)
    return attrs

def android_library_macro(**attrs):
    """Bazel android_library rule.

    https://docs.bazel.build/versions/master/be/android.html#android_library

    Args:
      **attrs: Rule attributes
    """
    android_library(**attrs_metadata(attrs))
