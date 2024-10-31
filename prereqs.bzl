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
            "https://github.com/bazelbuild/rules_java/releases/download/7.12.2/rules_java-7.12.2.tar.gz",
        ],
        sha256 = "a9690bc00c538246880d5c83c233e4deb83fe885f54c21bb445eb8116a180b83",
    )

    RULES_JVM_EXTERNAL_TAG = "6.5"
    RULES_JVM_EXTERNAL_SHA = "3a4d56357851cf5b0dae538b3f3e0612a4f58925dfb3cadb2e0c4e87d51e629e"

    maybe(
        http_archive,
        name = "rules_jvm_external",
        strip_prefix = "rules_jvm_external-%s" % RULES_JVM_EXTERNAL_TAG,
        sha256 = RULES_JVM_EXTERNAL_SHA,
        url = "https://github.com/bazelbuild/rules_jvm_external/releases/download/%s/rules_jvm_external-%s.tar.gz" % (RULES_JVM_EXTERNAL_TAG, RULES_JVM_EXTERNAL_TAG)
    )

    PROTOBUF_VERSION = "29.0-rc2"
    PROTOBUF_HASH = "ce5d00b78450a0ca400bf360ac00c0d599cc225f049d986a27e9a4e396c5a84a"
    maybe(
        http_archive,
        name = "protobuf",
        sha256 = PROTOBUF_HASH,
        strip_prefix = "protobuf-" + PROTOBUF_VERSION,
        urls = ["https://github.com/protocolbuffers/protobuf/archive/v" + PROTOBUF_VERSION + ".tar.gz"],
    )
    maybe(
        http_archive,
        name = "com_google_protobuf",
        sha256 = PROTOBUF_HASH,
        strip_prefix = "protobuf-" + PROTOBUF_VERSION,
        urls = ["https://github.com/protocolbuffers/protobuf/archive/v" + PROTOBUF_VERSION + ".tar.gz"],
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

    #maybe(
    http_archive(
        name = "bazel_skylib",
        sha256 = "bc283cdfcd526a52c3201279cda4bc298652efa898b10b4db0837dc51652756f",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
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
            "https://github.com/bazelbuild/rules_license/releases/download/1.0.0/rules_license-1.0.0.tar.gz",
        ],
        sha256 = "26d4021f6898e23b82ef953078389dd49ac2b5618ac564ade4ef87cced147b38",
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

    # Required by rules_go.
    maybe(
        http_archive,
        name = "rules_proto",
        sha256 = "6fb6767d1bef535310547e03247f7518b03487740c11b6c6adb7952033fe1295",
        strip_prefix = "rules_proto-6.0.2",
        url = "https://github.com/bazelbuild/rules_proto/releases/download/6.0.2/rules_proto-6.0.2.tar.gz",
    )

    maybe(
        http_archive,
        name = "rules_python",
        sha256 = "bd4797821b72b80b69e3c5ab4ad037e7fd1e6a0a27aebf42424c7ab0ce32e254",
        strip_prefix = "rules_python-0.37.1",
        url = "https://github.com/bazelbuild/rules_python/releases/download/0.37.1/rules_python-0.37.1.tar.gz",
    )

    maybe(
        http_archive,
        name = "bazel_worker_api",
        strip_prefix = "bazel-worker-api-0.0.1/proto",
        urls = [
            "https://github.com/bazelbuild/bazel-worker-api/releases/download/v0.0.1/bazel-worker-api-v0.0.1.tar.gz",
        ],
        sha256 = "b341e3fba0a3dd0ab7bfdc7e256fad711a1f9e9255563a74c305676046b5a184",
    )

    maybe(
        http_archive,
        name = "bazel_worker_java",
        strip_prefix = "bazel-worker-api-0.0.1/java",
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

    maybe(
        http_archive,
        name = "rules_cc",
        urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.0.13/rules_cc-0.0.13.tar.gz"],
        sha256 = "d9bdd3ec66b6871456ec9c965809f43a0901e692d754885e89293807762d3d80",
        strip_prefix = "rules_cc-0.0.13",
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
