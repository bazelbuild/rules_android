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

"""aar_import rule."""

load(
    "//rules:utils.bzl",
    "ANDROID_SDK_TOOLCHAIN_TYPE",
)
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load(":attrs.bzl", _ATTRS = "ATTRS")
load(":impl.bzl", _impl = "impl")
load(
    "//rules:providers.bzl",
    "StarlarkAndroidResourcesInfo",
)

RULE_DOC = """
#### Examples

The following example shows how to use `aar_import`.

```starlark
aar_import(
    name = "hellobazellib",
    aar = "lib.aar",
    package = "bazel.hellobazellib",
    deps = [
        "//java/bazel/hellobazellib/activities",
        "//java/bazel/hellobazellib/common",
    ],
)
```
"""

def _impl_proxy(ctx):
    providers, _ = _impl(ctx)
    return providers

aar_import = rule(
    attrs = _ATTRS,
    fragments = [
        "android",
        "bazel_android",  # NOTE: Only exists for Bazel
        "platform",
    ],
    implementation = _impl_proxy,
    doc = RULE_DOC,
    provides = [
        AndroidIdeInfo,
        AndroidLibraryResourceClassJarProvider,
        AndroidNativeLibsInfo,
        JavaInfo,
        StarlarkAndroidResourcesInfo,
    ],
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
        ANDROID_SDK_TOOLCHAIN_TYPE,
    ],
)
