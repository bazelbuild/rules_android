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

load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")
load("@bazel_skylib//:workspace.bzl", "bazel_skylib_workspace")
load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")
load("@io_bazel_rules_go//go:deps.bzl", "go_register_toolchains", "go_rules_dependencies")
load("@robolectric//bazel:robolectric.bzl", "robolectric_repositories")
load("@rules_java//java:repositories.bzl", "rules_java_dependencies", "rules_java_toolchains")
load("@rules_jvm_external//:defs.bzl", "maven_install")
load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies", "rules_proto_toolchains")
load("@rules_python//python:repositories.bzl", "py_repositories", "python_register_toolchains")

def rules_android_workspace():
    """ Sets up workspace dependencies for rules_android."""
    bazel_skylib_workspace()

    protobuf_deps()

    maven_install(
        name = "rules_android_maven",
        artifacts = [
            "androidx.privacysandbox.tools:tools:1.0.0-alpha06",
            "androidx.privacysandbox.tools:tools-apigenerator:1.0.0-alpha06",
            "androidx.privacysandbox.tools:tools-apipackager:1.0.0-alpha06",
            "androidx.test:core:1.6.0-alpha01",
            "androidx.test.ext:junit:1.2.0-alpha01",
            "com.android.tools.build:apksig:8.3.0-alpha18",
            "com.android.tools.build:bundletool:1.15.5",
            "com.android.tools:desugar_jdk_libs_minimal:2.0.4",
            "com.android.tools:desugar_jdk_libs_configuration_minimal:2.0.4",
            "com.android.tools:desugar_jdk_libs_nio:2.0.4",
            "com.android.tools:desugar_jdk_libs_configuration_nio:2.0.4",
            "com.android.tools.build:gradle:8.2.0-alpha15",
            "org.bouncycastle:bcprov-jdk18on:1.77",
            "org.hamcrest:hamcrest-core:2.2",
            "org.robolectric:robolectric:4.10.3",
            "com.google.guava:guava:32.1.2-jre",
            "com.google.protobuf:protobuf-java-util:3.9.2",
            "com.google.truth:truth:1.1.5",
            "info.picocli:picocli:4.7.4",
            "junit:junit:4.13.2",
        ],
        repositories = [
            "https://repo1.maven.org/maven2",
            "https://maven.google.com",
        ],
        use_starlark_android_rules = True,
        aar_import_bzl_label = "@rules_android//rules:rules.bzl",
        # To generate:
        # REPIN=1 bazelisk run --noenable_bzlmod @unpinned_rules_android_maven//:pin
        # maven_install_json = "//:rules_android_maven_install.json",
        # NOTE: above lockfile currently disabled due to https://github.com/bazelbuild/rules_jvm_external/issues/1134.
    )

    go_rules_dependencies()

    go_register_toolchains(version = "1.20.5")

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

    go_repository(
        name = "com_github_golang_glog",
        importpath = "github.com/golang/glog",
        version = "v1.1.2",
        sum = "h1:DVjP2PbBOzHyzA+dn3WhHIq4NdVu3Q+pvivFICf/7fo=",
    )

    robolectric_repositories()

    rules_java_dependencies()
    rules_java_toolchains()

    rules_proto_dependencies()
    rules_proto_toolchains()

    py_repositories()

    python_register_toolchains(
        name = "python3_11",
        # Available versions are listed in @rules_python//python:versions.bzl.
        # We recommend using the same version your team is already standardized on.
        python_version = "3.11",
    )
