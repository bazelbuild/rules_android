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

def rules_android_prereqs(dev_mode = False):
    """Downloads prerequisite repositories for rules_android."""
    maybe(
        http_archive,
        name = "rules_java",
        urls = [
            "https://github.com/bazelbuild/rules_java/releases/download/6.0.0/rules_java-6.0.0.tar.gz",
        ],
        sha256 = "469b7f3b580b4fcf8112f4d6d0d5a4ce8e1ad5e21fee67d8e8335d5f8b3debab",
    )

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
        sha256 = "51dc53293afe317d2696d4d6433a4c33feedb7748a9e352072e2ec3c0dafd2c6",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.40.1/rules_go-v0.40.1.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.40.1/rules_go-v0.40.1.zip",
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
        urls = ["https://github.com/robolectric/robolectric-bazel/archive/4.10.3.tar.gz"],
        strip_prefix = "robolectric-bazel-4.10.3",
        sha256 = "1b199a932cbde4af728dd8275937091adbb89a4bf63d326de49e6d0a42e723bf",
    )

    maybe(
        http_archive,
        name = "rules_license",
        urls = [
            "https://github.com/bazelbuild/rules_license/releases/download/0.0.4/rules_license-0.0.4.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/rules_license/releases/download/0.0.4/rules_license-0.0.4.tar.gz",
        ],
        sha256 = "6157e1e68378532d0241ecd15d3c45f6e5cfd98fc10846045509fb2a7cc9e381",
    )

    maybe(
        http_archive,
        name = "py_absl",
        sha256 = "0fb3a4916a157eb48124ef309231cecdfdd96ff54adf1660b39c0d4a9790a2c0",
        urls = [
            "https://github.com/abseil/abseil-py/archive/refs/tags/v1.4.0.tar.gz",
        ],
        strip_prefix = "abseil-py-1.4.0",
    )

    maybe(
        http_archive,
        name = "rules_proto",
        sha256 = "dc3fb206a2cb3441b485eb1e423165b231235a1ea9b031b4433cf7bc1fa460dd",
        strip_prefix = "rules_proto-5.3.0-21.7",
        urls = [
            "https://github.com/bazelbuild/rules_proto/archive/refs/tags/5.3.0-21.7.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "rules_python",
        strip_prefix = "rules_python-0.23.1",
        urls = [
            "https://github.com/bazelbuild/rules_python/releases/download/0.23.1/rules_python-0.23.1.tar.gz",
            "https://mirror.bazel.build/github.com/bazelbuild/rules_python/releases/download/0.23.1/rules_python-0.23.1.tar.gz",
        ],
        sha256 = "84aec9e21cc56fbc7f1335035a71c850d1b9b5cc6ff497306f84cced9a769841",
    )

    if dev_mode:
        maybe(
            http_archive,
            name = "rules_bazel_integration_test",
            sha256 = "d6dada79939533a8127000d2aafa125f29a4a97f720e01c050fdeb81b1080b08",
            urls = [
                "https://github.com/bazel-contrib/rules_bazel_integration_test/releases/download/v0.17.0/rules_bazel_integration_test.v0.17.0.tar.gz",
            ],
        )

        maybe(
            http_archive,
            name = "cgrindel_bazel_starlib",
            sha256 = "a8d25340956b429b56302d3fd702bb3df8b3a67db248dd32b3084891ad497964",
            urls = [
                "https://github.com/cgrindel/bazel-starlib/releases/download/v0.17.0/bazel-starlib.v0.17.0.tar.gz",
            ],
        )
