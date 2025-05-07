# Copyright 2022 The Bazel Authors. All rights reserved.
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
"""Module extension to declare Android runtime dependencies for Bazel."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_jar")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

def _remote_android_tools_extensions_impl(module_ctx):
    http_archive(
        name = "android_tools",
        sha256 = "d7cdfc03f3ad6571b7719f4355379177a4bde68d17dca2bdbf6c274d72e4d6cf",
        url = "https://mirror.bazel.build/bazel_android_tools/android_tools_pkg-0.31.0.tar",
    )
    http_jar(
        name = "android_gmaven_r8",
        sha256 = "204b2fc2b0f4e888dc0ef748b58090def1bf4185068d36abbb94841dbc7107a8",
        url = "https://maven.google.com/com/android/tools/r8/8.9.35/r8-8.9.35.jar",
    )
    return module_ctx.extension_metadata(reproducible = True)

remote_android_tools_extensions = module_extension(
    implementation = _remote_android_tools_extensions_impl,
)
