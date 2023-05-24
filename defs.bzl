# Copyright 2021 The Bazel Authors. All rights reserved.
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

"""Workspace setup macro for rules_android."""

load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")
load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@robolectric//bazel:robolectric.bzl", "robolectric_repositories")
load("@rules_jvm_external//:defs.bzl", "maven_install")

def rules_android_workspace():
    """ Sets up workspace dependencies for rules_android."""
    bazel_skylib_workspace()

    protobuf_deps()

    maven_install(
        name = "rules_android_maven",
        artifacts = [
            "com.android.tools.build:bundletool:1.6.1",
            "com.android.tools.build:gradle:8.0.1",
        ],
        repositories = [
            "https://maven.google.com",
            "https://repo1.maven.org/maven2",
        ],
    )

    go_rules_dependencies()

    go_register_toolchains(version = "1.18.3")

    gazelle_dependencies()
    # gazelle:repository go_repository name=org_golang_x_xerrors importpath=golang.org/x/xerrors

    go_repository(
        name = "org_golang_google_protobuf",
        importpath = "google.golang.org/protobuf",
        sum = "h1:d0NfwRgPtno5B1Wa6L2DAG+KivqkdutMf1UhdNx175w=",
        version = "v1.28.1",
    )

    go_repository(
        name = "com_github_google_go_cmp",
        importpath = "github.com/google/go-cmp",
        sum = "h1:O2Tfq5qg4qc4AmwVlvv0oLiVAGB7enBSJ2x2DqQFi38=",
        version = "v0.5.9",
    )

    go_repository(
      name = "org_golang_x_sync",
      importpath = "golang.org/x/sync",
      sum = "h1:5KslGYwFpkhGh+Q16bwMP3cOontH8FOep7tGV86Y7SQ=",
      version = "v0.0.0-20210220032951-036812b2e83c",
    )

    robolectric_repositories()


