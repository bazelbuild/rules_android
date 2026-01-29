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
load("//bzlmod_extensions:com_android_dex.bzl", _com_android_dex_archive = "com_android_dex")

def rules_android_prereqs(dev_mode = False):
    """Downloads prerequisite repositories for rules_android."""

    maybe(
        http_archive,
        name = "bazel_features",
        sha256 = "a660027f5a87f13224ab54b8dc6e191693c554f2692fcca46e8e29ee7dabc43b",
        strip_prefix = "bazel_features-1.30.0",
        url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.30.0/bazel_features-v1.30.0.tar.gz",
    )

    maybe(
        http_archive,
        name = "rules_java",
        urls = [
            "https://github.com/bazelbuild/rules_java/releases/download/9.2.0/rules_java-9.2.0.tar.gz",
        ],
        sha256 = "2f822fbc33b99de5bbeaceada4be2bd3bb5c8da80e2f7462a9d300c8fc312f11",
    )

    maybe(
        http_archive,
        name = "rules_cc",
        urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.2.14/rules_cc-0.2.14.tar.gz"],
        sha256 = "a2fdfde2ab9b2176bd6a33afca14458039023edb1dd2e73e6823810809df4027",
        strip_prefix = "rules_cc-0.2.14",
    )

    maybe(
        http_archive,
        name = "android_tools",
        sha256 = "d7cdfc03f3ad6571b7719f4355379177a4bde68d17dca2bdbf6c274d72e4d6cf",
        url = "https://mirror.bazel.build/bazel_android_tools/android_tools_pkg-0.31.0.tar",
    )

    RULES_JVM_EXTERNAL_TAG = "6.9"
    RULES_JVM_EXTERNAL_SHA = "3c41eae4226a7dfdce7b213bc541557b8475c92da71e2233ec7c306630243a65"
    maybe(
        http_archive,
        name = "rules_jvm_external",
        strip_prefix = "rules_jvm_external-%s" % RULES_JVM_EXTERNAL_TAG,
        sha256 = RULES_JVM_EXTERNAL_SHA,
        url = "https://github.com/bazelbuild/rules_jvm_external/releases/download/%s/rules_jvm_external-%s.tar.gz" % (RULES_JVM_EXTERNAL_TAG, RULES_JVM_EXTERNAL_TAG),
    )

    PROTOBUF_VERSION = "33.4"
    PROTOBUF_HASH = "bc670a4e34992c175137ddda24e76562bb928f849d712a0e3c2fb2e19249bea1"
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
        sha256 = "51b5105a760b353773f904d2bbc5e664d0987fbaf22265164de65d43e910d8ac",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.8.1/bazel-skylib-1.8.1.tar.gz",
        ],
    )

    maybe(
        http_archive,
        name = "io_bazel_rules_go",
        sha256 = "68af54cb97fbdee5e5e8fe8d210d15a518f9d62abfd71620c3eaff3b26a5ff86",
        urls = [
            "https://mirror.bazel.build/github.com/bazel-contrib/rules_go/releases/download/v0.59.0/rules_go-v0.59.0.zip",
            "https://github.com/bazel-contrib/rules_go/releases/download/v0.59.0/rules_go-v0.59.0.zip",
        ],
    )

    maybe(
        http_archive,
        name = "bazel_gazelle",
        sha256 = "675114d8b433d0a9f54d81171833be96ebc4113115664b791e6f204d58e93446",
        urls = [
            "https://mirror.bazel.build/github.com/bazelbuild/bazel-gazelle/releases/download/v0.47.0/bazel-gazelle-v0.47.0.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/v0.47.0/bazel-gazelle-v0.47.0.tar.gz",
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
        sha256 = "14a225870ab4e91869652cfd69ef2028277fc1dc4910d65d353b62d6e0ae21f4",
        strip_prefix = "rules_proto-7.1.0",
        url = "https://github.com/bazelbuild/rules_proto/releases/download/7.1.0/rules_proto-7.1.0.tar.gz",
    )

    maybe(
        http_archive,
        name = "rules_python",
        sha256 = "fa7dd2c6b7d63b3585028dd8a90a6cf9db83c33b250959c2ee7b583a6c130e12",
        strip_prefix = "rules_python-1.6.0",
        url = "https://github.com/bazelbuild/rules_python/releases/download/1.6.0/rules_python-1.6.0.tar.gz",
    )

    BAZEL_WORKER_API_VERSION = "0.0.10"
    BAZEL_WORKER_API_HASH = "0476fe27251cd3234b69737f8bc231cfe9912becdd620e07e2d73c87bcc7e40a"
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
            "https://mirror.bazel.build/github.com/bazelbuild/rules_shell/releases/download/v0.6.1/rules_shell-v0.6.1.tar.gz",
            "https://github.com/bazelbuild/rules_shell/releases/download/v0.6.1/rules_shell-v0.6.1.tar.gz",
        ],
        sha256 = "e6b87c89bd0b27039e3af2c5da01147452f240f75d505f5b6880874f31036307",
        strip_prefix = "rules_shell-0.6.1",
    )

    maybe(
        http_archive,
        name = "rules_cc",
        urls = ["https://github.com/bazelbuild/rules_cc/releases/download/0.2.14/rules_cc-0.2.14.tar.gz"],
        sha256 = "a2fdfde2ab9b2176bd6a33afca14458039023edb1dd2e73e6823810809df4027",
        strip_prefix = "rules_cc-0.2.14",
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
        sha256 = "51b5105a760b353773f904d2bbc5e664d0987fbaf22265164de65d43e910d8ac",
        urls = [
            "https://github.com/bazelbuild/bazel-skylib/releases/download/1.8.1/bazel-skylib-1.8.1.tar.gz",
        ],
    )

    _apksig_archive()
    _com_android_dex_archive()

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
            sha256 = "dfa423dbf5aac0a5217d3780b295abd3ea1c633d5f9198712b23f0f14f2e8d92",
            urls = [
                "https://github.com/cgrindel/bazel-starlib/releases/download/v0.18.0/bazel-starlib.v0.18.0.tar.gz",
            ],
        )
