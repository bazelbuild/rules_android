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

load("//rules:acls.bzl", "acls")
load(":attrs.bzl", _ATTRS = "ATTRS")
load(":impl.bzl", _impl = "impl")
load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)

_RULE_DOC = """
#### Examples

The following example shows how to use android libraries with resources.

```starlark
android_library(
    name = "hellobazellib",
    srcs = glob(["*.java"]),
    resource_files = glob(["res/**/*"]),
    manifest = "AndroidManifest.xml",
    deps = [
        "//java/bazel/hellobazellib/activities",
        "//java/bazel/hellobazellib/common",
        "//java/bazel/hellobazellib/math",
        "//java/bazel/hellobazellib/service",
    ],
)
```

The following example shows how to set `idl_import_root`. Let `//java/bazel/helloandroid/BUILD` contain:

```starlark
android_library(
    name = "parcelable",
    srcs = ["MyParcelable.java"], # bazel.helloandroid.MyParcelable
    # MyParcelable.aidl will be used as import for other .aidl
    # files that depend on it, but will not be compiled.
    idl_parcelables = ["MyParcelable.aidl"] # bazel.helloandroid.MyParcelable
    # We don't need to specify idl_import_root since the aidl file
    # which declares bazel.helloandroid.MyParcelable
    # is present at java/bazel/helloandroid/MyParcelable.aidl
    # underneath a java root (java/).
)

android_library(
    name = "foreign_parcelable",
    srcs = ["src/android/helloandroid/OtherParcelable.java"], # android.helloandroid.OtherParcelable
    idl_parcelables = [
        "src/android/helloandroid/OtherParcelable.aidl" # android.helloandroid.OtherParcelable
    ],
    # We need to specify idl_import_root because the aidl file which
    # declares android.helloandroid.OtherParcelable is not positioned
    # at android/helloandroid/OtherParcelable.aidl under a normal java root.
    # Setting idl_import_root to "src" in //java/bazel/helloandroid
    # adds java/bazel/helloandroid/src to the list of roots
    # the aidl compiler will search for imported types.
    idl_import_root = "src",
)

# Here, OtherInterface.aidl has an "import android.helloandroid.CallbackInterface;" statement.
android_library(
    name = "foreign_interface",
    idl_srcs = [
        "src/android/helloandroid/OtherInterface.aidl" # android.helloandroid.OtherInterface
        "src/android/helloandroid/CallbackInterface.aidl" # android.helloandroid.CallbackInterface
    ],
    # As above, idl_srcs which are not correctly positioned under a java root
    # must have idl_import_root set. Otherwise, OtherInterface (or any other
    # interface in a library which depends on this one) will not be able
    # to find CallbackInterface when it is imported.
    idl_import_root = "src",
)

# MyParcelable.aidl is imported by MyInterface.aidl, so the generated
# MyInterface.java requires MyParcelable.class at compile time.
# Depending on :parcelable ensures that aidl compilation of MyInterface.aidl
# specifies the correct import roots and can access MyParcelable.aidl, and
# makes MyParcelable.class available to Java compilation of MyInterface.java
# as usual.
android_library(
    name = "idl",
    idl_srcs = ["MyInterface.aidl"],
    deps = [":parcelable"],
)

# Here, ServiceParcelable uses and thus depends on ParcelableService,
# when it's compiled, but ParcelableService also uses ServiceParcelable,
# which creates a circular dependency.
# As a result, these files must be compiled together, in the same android_library.
android_library(
    name = "circular_dependencies",
    srcs = ["ServiceParcelable.java"],
    idl_srcs = ["ParcelableService.aidl"],
    idl_parcelables = ["ServiceParcelable.aidl"],
)
```
"""

def _outputs(name, _package_name, _defined_local_resources):
    outputs = dict(
        lib_jar = "lib%{name}.jar",
        lib_src_jar = "lib%{name}-src.jar",
        aar = "%{name}.aar",
    )

    if _defined_local_resources:
        # TODO(b/177261846): resource-related predeclared outputs need to be re-pointed at the
        # corresponding artifacts in the Starlark pipeline.
        label = "//" + _package_name + ":" + name
        if acls.in_android_library_starlark_resource_outputs_rollout(label):
            path_prefix = "_migrated/"
        else:
            path_prefix = ""
        outputs.update(
            dict(
                resources_src_jar = path_prefix + "%{name}.srcjar",
                resources_txt = path_prefix + "%{name}_symbols/R.txt",
                resources_jar = path_prefix + "%{name}_resources.jar",
            ),
        )

    return outputs

def make_rule(
        attrs = _ATTRS,
        implementation = _impl,
        outputs = _outputs,
        additional_toolchains = [],
        additional_providers = []):
    """Makes the rule.

    Args:
      attrs: A dict. The attributes for the rule.
      implementation: A function. The rule's implementation method.
      outputs: A dict, function, or None. The rule's outputs.
      additional_toolchains: A list. Additional toolchains passed to pass to rule(toolchains).
      additional_providers: A list. Additional providers passed to pass to rule(providers).

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
        doc = _RULE_DOC,
        provides = [
            AndroidCcLinkParamsInfo,
            AndroidIdeInfo,
            AndroidIdlInfo,
            AndroidLibraryResourceClassJarProvider,
            AndroidNativeLibsInfo,
            JavaInfo,
        ] + additional_providers,
        outputs = outputs,
        toolchains = [
            "//toolchains/android:toolchain_type",
            "//toolchains/android_sdk:toolchain_type",
            "@bazel_tools//tools/jdk:toolchain_type",
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

    # Required for ACLs check in _outputs(), since the callback can't access
    # the native module.
    attrs["$package_name"] = native.package_name()

    return attrs

def android_library_macro(**attrs):
    """Bazel android_library rule.

    https://docs.bazel.build/versions/master/be/android.html#android_library

    Args:
      **attrs: Rule attributes
    """
    android_library(**attrs_metadata(attrs))
