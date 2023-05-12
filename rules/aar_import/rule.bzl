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

load(":attrs.bzl", _ATTRS = "ATTRS")
load(":impl.bzl", _impl = "impl")

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

aar_import = rule(
    attrs = _ATTRS,
    fragments = ["android"],
    implementation = _impl,
    doc = RULE_DOC,
    provides = [
        AndroidIdeInfo,
        AndroidLibraryResourceClassJarProvider,
        AndroidNativeLibsInfo,
        JavaInfo,
    ],
    toolchains = ["//toolchains/android:toolchain_type"],
)
