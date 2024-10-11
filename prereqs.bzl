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
load("//bzlmod_extensions:apksig.bzl", _apksig_archive = "apksig")

def rules_android_prereqs(dev_mode = False):
    """Downloads prerequisite repositories for rules_android."""
    maybe(
        http_archive,
        name = "rules_java",
        urls = [
            "https://github.com/bazelbuild/rules_java/releases/download/7.11.1/rules_java-7.11.1.tar.gz",
        ],
        sha256 = "6f3ce0e9fba979a844faba2d60467843fbf5191d8ca61fa3d2ea17655b56bb8c",
    )

    RULES_JVM_EXTERNAL_TAG = "6.2"
    RULES_JVM_EXTERNAL_SHA = "808cb5c30b5f70d12a2a745a29edc46728fd35fa195c1762a596b63ae9cebe05"

    maybe(
        http_archive,
        name = "rules_jvm_external",
        strip_prefix = "rules_jvm_external-%s" % RULES_JVM_EXTERNAL_TAG,
        sha256 = RULES_JVM_EXTERNAL_SHA,
        url = "https://github.com/bazelbuild/rules_jvm_external/releases/download/%s/rules_jvm_external-%s.tar.gz" % (RULES_JVM_EXTERNAL_TAG, RULES_JVM_EXTERNAL_TAG)
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
        sha256 = "33acc4ae0f70502db4b893c9fc1dd7a9bf998c23e7ff2c4517741d4049a976f8",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_go/releases/download/v0.48.0/rules_go-v0.48.0.zip",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.48.0/rules_go-v0.48.0.zip",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "d76bf7a60fd8b050444090dfa2837a4eaf9829e1165618ee35dceca5cbdf58d5",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.37.0/bazel-gazelle-v0.37.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.37.0/bazel-gazelle-v0.37.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "robolectric",
        urls = ["https://github.com/robolectric/robolectric-bazel/archive/4.11.1.tar.gz"],
        strip_prefix = "robolectric-bazel-4.11.1",
        sha256 = "1ea1cfe67848decf959316e80dd69af2bbaa359ae2195efe1366cbdf3e968356",
        patch_args = ["-p1"],
        patches = [Label("//:robolectric-bazel.patch")],
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

    # Required by rules_proto.
    maybe(
        http_archive,
        name = "bazel_features",
        sha256 = "d7787da289a7fb497352211ad200ec9f698822a9e0757a4976fd9f713ff372b3",
        strip_prefix = "bazel_features-1.9.1",
        url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.9.1/bazel_features-v1.9.1.tar.gz",
    )

    # Required by rules_go.
    maybe(
        http_archive,
        name = "rules_proto",
        sha256 = "303e86e722a520f6f326a50b41cfc16b98fe6d1955ce46642a5b7a67c11c0f5d",
        strip_prefix = "rules_proto-6.0.0",
        url = "https://github.com/bazelbuild/rules_proto/releases/download/6.0.0/rules_proto-6.0.0.tar.gz",
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

    maybe(
        http_archive,
        name = "bazel_worker_api",
        strip_prefix = "bazel-worker-api-0.0.1/proto",
        patch_cmds = [
            "find . -name 'BUILD.bazel' -exec sed -i 's/maven/rules_android_maven/g' {} \\;",
        ],
        urls = [
            "https://github.com/bazelbuild/bazel-worker-api/releases/download/v0.0.1/bazel-worker-api-v0.0.1.tar.gz",
        ],
        sha256 = "b341e3fba0a3dd0ab7bfdc7e256fad711a1f9e9255563a74c305676046b5a184",
    )

    maybe(
        http_archive,
        name = "bazel_worker_java",
        strip_prefix = "bazel-worker-api-0.0.1/java",
        patch_cmds = [
            "find . -name 'BUILD.bazel' -exec sed -i 's/maven/rules_android_maven/g' {} \\;",
        ],
        urls = [
            "https://github.com/bazelbuild/bazel-worker-api/releases/download/v0.0.1/bazel-worker-api-v0.0.1.tar.gz",
        ],
        sha256 = "b341e3fba0a3dd0ab7bfdc7e256fad711a1f9e9255563a74c305676046b5a184",
    )

    maybe(
        http_archive,
        name = "rules_shell",
        sha256 = "a86bcdcfb7a14267fa81bd18e199a53315b864a89378a7eecd3db739bfa436e2",
        strip_prefix = "rules_shell-0.1.2",
        url = "https://github.com/bazelbuild/rules_shell/releases/download/v0.1.2/rules_shell-v0.1.2.tar.gz",
    )

    _apksig_archive()

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
