# Copyright 2025 The Bazel Authors. All rights reserved.
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
"""Module extension to enable building com.android.dex."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

def com_android_dex(_ctx = None):
    # NOTE(b/317109605): Cannot depend on a stable sha256 hash for googlesource repositories.
    http_archive(
        name = "com_android_dex",
        url = "https://android.googlesource.com/platform/dalvik/+archive/5a81c499a569731e2395f7c8d13c0e0d4e17a2b6.tar.gz",
        build_file = Label("//bzlmod_extensions:com_android_dex.BUILD"),
    )

com_android_dex_extension = module_extension(
    implementation = com_android_dex,
)
