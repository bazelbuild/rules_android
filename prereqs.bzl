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

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_jar")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("//bzlmod_extensions:apksig.bzl", _apksig_archive = "apksig")

def rules_android_prereqs(dev_mode = False):
    """Downloads prerequisite repositories for rules_android."""

    maybe(
        http_archive,
        name = "rules_java",
        urls = [
            "https://github.com/bazelbuild/rules_java/releases/download/8.6.3/rules_java-8.6.3.tar.gz",
        ],
        sha256 = "6d8c6d5cd86fed031ee48424f238fa35f33abc9921fd97dd4ae1119a29fc807f",
    )

    maybe(
        http_archive,
        name = "android_tools",
        sha256 = "d7cdfc03f3ad6571b7719f4355379177a4bde68d17dca2bdbf6c274d72e4d6cf",
        url = "https://mirror.bazel.build/bazel_android_tools/android_tools_pkg-0.31.0.tar",
    )

    maybe(
        http_jar,
        name = "android_gmaven_r8",
        sha256 = "59753e70a74f918389cc87f1b7d66b5c0862932559167425708ded159e3de439",
        url = "https://maven.google.com/com/android/tools/r8/8.3.37/r8-8.3.37.jar",
    )

    RULES_JVM_EXTERNAL_TAG = "6.6"
    RULES_JVM_EXTERNAL_SHA = "3afe5195069bd379373528899c03a3072f568d33bd96fe037bd43b1f590535e7"
    maybe(
        http_archive,
        name = "rules_jvm_external",
        strip_prefix = "rules_jvm_external-%s" % RULES_JVM_EXTERNAL_TAG,
        sha256 = RULES_JVM_EXTERNAL_SHA,
        url = "https://github.com/bazelbuild/rules_jvm_external/releases/download/%s/rules_jvm_external-%s.tar.gz" % (RULES_JVM_EXTERNAL_TAG, RULES_JVM_EXTERNAL_TAG),
    )

    PROTOBUF_VERSION = "29.0"
    PROTOBUF_HASH = "10a0d58f39a1a909e95e00e8ba0b5b1dc64d02997f741151953a2b3659f6e78c"
    maybe(
        http_archive,
        name = "com_google_protobuf",
        sha256 = PROTOBUF_HASH,
        strip_prefix = "protobuf-" + PROTOBUF_VERSION,
        urls = ["https://github.com/protocolbuffers/protobuf/releases/download/v{0}/protobuf-{0}.tar.gz".format(PROTOBUF_VERSION)],
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
        sha256 = "1101d7e81a6e7f9cee94dd947bed705144bf339257fbec1d73d620df87e58885",
        urls = [
            "https://mirror.bazel.build/github.com/bazel-contrib/rules_go/releases/download/v0.51.0-rc2/rules_go-v0.51.0-rc2.zip",
            "https://github.com/bazel-contrib/rules_go/releases/download/v0.51.0-rc2/rules_go-v0.51.0-rc2.zip",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "a80893292ae1d78eaeedd50d1cab98f242a17e3d5741b1b9fb58b5fd9d2d57bc",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.40.0/bazel-gazelle-v0.40.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.40.0/bazel-gazelle-v0.40.0.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "robolectric",
        sha256 = "b2d2164bae80fcfbdd078eb2f0935ba06557402b8c814928d9e3bec7358e2b7b",
        strip_prefix = "robolectric-bazel-4.14.1.2",
        urls = ["https://github.com/robolectric/robolectric-bazel/releases/download/4.14.1.2/robolectric-bazel-4.14.1.2.tar.gz"],
    )

    http_archive(
        name = "rules_license",
        urls = [
            "https://github.com/bazelbuild/rules_license/releases/download/1.0.0/rules_license-1.0.0.tar.gz",
        ],
        sha256 = "26d4021f6898e23b82ef953078389dd49ac2b5618ac564ade4ef87cced147b38",
    )

    maybe(
        http_archive,
        name = "py_absl",
        sha256 = "8a3d0830e4eb4f66c4fa907c06edf6ce1c719ced811a12e26d9d3162f8471758",
        urls = [
            "https://github.com/abseil/abseil-py/archive/refs/tags/v2.1.0.tar.gz",
        ],
        strip_prefix = "abseil-py-2.1.0",
    )

    # Required by rules_go.
    maybe(
        http_archive,
        name = "rules_proto",
        sha256 = "0e5c64a2599a6e26c6a03d6162242d231ecc0de219534c38cb4402171def21e8",
        strip_prefix = "rules_proto-7.0.2",
        url = "https://github.com/bazelbuild/rules_proto/releases/download/7.0.2/rules_proto-7.0.2.tar.gz",
    )

    maybe(
        http_archive,
        name = "rules_python",
        sha256 = "690e0141724abb568267e003c7b6d9a54925df40c275a870a4d934161dc9dd53",
        strip_prefix = "rules_python-0.40.0",
        url = "https://github.com/bazelbuild/rules_python/releases/download/0.40.0/rules_python-0.40.0.tar.gz",
    )

    BAZEL_WORKER_API_VERSION = "0.0.4"
    BAZEL_WORKER_API_HASH = "79b30bcdab8cb0dce1523b28ff798067419715f5540a8a446bbccf393e5eb79c"
    maybe(
        http_archive,
        name = "bazel_worker_api",
        strip_prefix = "bazel-worker-api-%s/proto" % BAZEL_WORKER_API_VERSION,
        urls = [
            "https://github.com/bazelbuild/bazel-worker-api/releases/download/v{0}/bazel-worker-api-v{0}.tar.gz".format(BAZEL_WORKER_API_VERSION),
        ],
        sha256 = BAZEL_WORKER_API_HASH,
    )
    maybe(
        http_archive,
        name = "bazel_worker_java",
        strip_prefix = "bazel-worker-api-%s/java" % BAZEL_WORKER_API_VERSION,
        urls = [
            "https://github.com/bazelbuild/bazel-worker-api/releases/download/v{0}/bazel-worker-api-v{0}.tar.gz".format(BAZEL_WORKER_API_VERSION),
        ],
        sha256 = BAZEL_WORKER_API_HASH,
    )

    maybe(
        http_archive,
        name = "rules_shell",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/rules_shell/releases/download/v0.3.0/rules_shell-v0.3.0.tar.gz",
            "https://github.com/bazelbuild/rules_shell/releases/download/v0.3.0/rules_shell-v0.3.0.tar.gz",
        ],
        sha256 = "d8cd4a3a91fc1dc68d4c7d6b655f09def109f7186437e3f50a9b60ab436a0c53",
        strip_prefix = "rules_shell-0.3.0",
    )

    maybe(
        http_archive,
        name = "rules_cc",
        urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.0.16/rules_cc-0.0.16.tar.gz"],
        sha256 = "bbf1ae2f83305b7053b11e4467d317a7ba3517a12cef608543c1b1c5bf48a4df",
        strip_prefix = "rules_cc-0.0.16",
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
        name = "bazel_skylib",
        sha256 = "bc283cdfcd526a52c3201279cda4bc298652efa898b10b4db0837dc51652756f",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.7.1/bazel-skylib-1.7.1.tar.gz",
        ],
    )

    # This is only needed for bazel 8.0.0rc4
    http_archive(
        name = "bazel_features",
        sha256 = "af3d4fb1cf4f25942cb4a933b1ad93a0ea9fe9ee70c2af7f369fb72a67c266e5",
        strip_prefix = "bazel_features-1.21.0",
        url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.21.0/bazel_features-v1.21.0.tar.gz",
    )

    _apksig_archive()

    if dev_mode:
        maybe(
            http_archive,
            name = "rules_bazel_integration_test",
            sha256 = "04d7816612a7aa25b1d9cd40e4bbad7e7da7a7731cf4a9bece69e9711ea26d4b",
            urls = [
                "https://github.com/bazel-contrib/rules_bazel_integration_test/releases/download/v0.27.0/rules_bazel_integration_test.v0.27.0.tar.gz",
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
