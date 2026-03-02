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
"""Module extension to enable building apksigner."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

APKSIG_COMMIT = "24e3075e68ebe17c0b529bb24bfda819db5e2f3b"

def apksig(_ctx = None):
    # NOTE(b/317109605): Cannot depend on a stable sha256 hash for googlesource repositories.
    http_archive(
        name = "apksig",
        urls = [
            # Original download URL. Does not always return stable sha256sums, and can flake out.
            # "https://android.googlesource.com/platform/tools/apksig/+archive/%s.tar.gz" % APKSIG_COMMIT,
            "https://mirror.bazel.build/android.googlesource.com/platform/tools/apksig/+archive/%s.tar.gz" % APKSIG_COMMIT,
        ],
        sha256 = "12e44fdbd219c5e1cc62099c2a01d775957603d2d4f693f8285f9d95d9a04e77",
        build_file = Label("//bzlmod_extensions:apksig.BUILD"),
    )

apksig_extension = module_extension(
    implementation = apksig,
)
