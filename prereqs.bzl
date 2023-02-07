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

"""Sets up prerequisites for rules_android."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")


def rules_android_prereqs():
    """Downloads prerequisite repositories for rules_android."""
    maybe(
        http_archive,
        name = "rules_jvm_external",
        strip_prefix = "rules_jvm_external-fa73b1a8e4846cee88240d0019b8f80d39feb1c3",
        sha256 = "7e13e48b50f9505e8a99cc5a16c557cbe826e9b68d733050cd1e318d69f94bb5",
        url = "https://github.com/bazelbuild/rules_jvm_external/archive/fa73b1a8e4846cee88240d0019b8f80d39feb1c3.zip",
    )

    maybe(
        http_archive,
        name = "com_google_protobuf",
        sha256 = "87407cd28e7a9c95d9f61a098a53cf031109d451a7763e7dd1253abf8b4df422",
        strip_prefix = "protobuf-3.19.1",
        urls = ["https://github.com/protocolbuffers/protobuf/archive/v3.19.1.tar.gz"],
    )

    maybe(
        http_archive,
        name = "remote_java_tools_for_rules_android",
        sha256 = "8fb4d3138bd92a9d3324dae29c9f70d91ca2db18cd0bf1997446eed4657d19b3",
        urls = [
                "https://mirror.bazel.build/bazel_java_tools/releases/java/v11.8/java_tools-v11.8.zip",
                "https://github.com/bazelbuild/java_tools/releases/download/java_v11.8/java_tools-v11.8.zip",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_skylib",
        sha256 = "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "16e9fca53ed6bd4ff4ad76facc9b7b651a89db1689a2877d6fd7b82aa824e366",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.34.0/rules_go-v0.34.0.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.34.0/rules_go-v0.34.0.zip",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "5982e5463f171da99e3bdaeff8c0f48283a7a5f396ec5282910b9e8a49c0dd7e",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.25.0/bazel-gazelle-v0.25.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.25.0/bazel-gazelle-v0.25.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "robolectric",
        urls = ["https://github.com/robolectric/robolectric-bazel/archive/4.9.2.tar.gz"],
        strip_prefix = "robolectric-bazel-4.9.2",
        sha256 = "7e007fcfdca7b7228cb4de72707e8b317026ea95000f963e91d5ae365be52d0d",
    )


