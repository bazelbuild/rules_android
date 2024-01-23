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

APKSIG_COMMIT = "24e3075e68ebe17c0b529bb24bfda819db5e2f3b"

def apksig(_ctx = None):
    # NOTE(b/317109605): Cannot depend on a stable sha256 hash for googlesource repositories.
    http_archive(
        name = "apksig",
        url = "https://android.googlesource.com/platform/tools/apksig/+archive/%s.tar.gz" % APKSIG_COMMIT,
        build_file = Label("//bzlmod_extensions:apksig.BUILD"),
    )

apksig_extension = module_extension(
    implementation = apksig,
)
