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
load(
    "@io_bazel_rules_go//go:deps.bzl",
    "go_download_sdk",
    "go_register_toolchains",
    "go_rules_dependencies",
)
load("@robolectric//bazel:robolectric.bzl", "robolectric_repositories")
load("@rules_jvm_external//:defs.bzl", "maven_install")
load("@rules_proto//proto:repositories.bzl", "rules_proto_dependencies")
load("@rules_proto//proto:setup.bzl", "rules_proto_setup")
load("@rules_proto//proto:toolchains.bzl", "rules_proto_toolchains")
load("@rules_python//python:repositories.bzl", "py_repositories", "python_register_toolchains")
load("@rules_shell//shell:repositories.bzl", "rules_shell_dependencies", "rules_shell_toolchains")

def rules_android_workspace():
    """ Sets up workspace dependencies for rules_android."""

    protobuf_deps()

    bazel_skylib_workspace()

    # Maven for android_ide_common need to be separated into their own separate maven_install for now
    # due to compatibility issues with newer versions.
    maven_install(
        name = "android_ide_common_30_1_3",
        aar_import_bzl_label = "@rules_android//rules:rules.bzl",
        artifacts = [
            "com.android.tools.layoutlib:layoutlib-api:30.1.3",
            "com.android.tools.build:manifest-merger:30.1.3",
            "com.android.tools:common:30.1.3",
            "com.android.tools:repository:30.1.3",
            "com.android.tools.analytics-library:protos:30.1.3",
            "com.android.tools.analytics-library:shared:30.1.3",
            "com.android.tools.analytics-library:tracker:30.1.3",
            "com.android.tools:annotations:30.1.3",
            "com.android.tools:sdk-common:30.1.3",
            "com.android.tools.build:builder:7.1.3",
            "com.android.tools.build:builder-model:7.1.3",
            # These technically aren't needed, but the protobuf version pulled
            # in by these older deps has compatibility issues with the newer
            # protobuf runtimes.
            "com.google.protobuf:protobuf-java:4.31.1",
            "com.google.protobuf:protobuf-java-util:4.31.1",
        ],
        repositories = [
            "https://maven.google.com",
            "https://repo1.maven.org/maven2",
        ],
        use_starlark_android_rules = True,
    )

    maven_install(
        name = "rules_android_maven",
        artifacts = [
            "androidx.privacysandbox.tools:tools:1.0.0-alpha06",
            "androidx.privacysandbox.tools:tools-apigenerator:1.0.0-alpha06",
            "androidx.privacysandbox.tools:tools-apipackager:1.0.0-alpha06",
            "androidx.test:core:1.6.0-alpha01",
            "androidx.test.ext:junit:1.2.0-alpha01",
            "com.android.tools.apkdeployer:apkdeployer:8.11.0-alpha10",
            "com.android.tools.build:bundletool:1.15.5",
            "com.android.tools:desugar_jdk_libs_minimal:2.1.5",
            "com.android.tools:desugar_jdk_libs_configuration_minimal:2.1.5",
            "com.android.tools:desugar_jdk_libs_nio:2.1.5",
            "com.android.tools:desugar_jdk_libs_configuration_nio:2.1.5",
            "com.android.tools:desugar_jdk_libs_configuration:2.1.5",
            "com.android.tools:r8:8.9.35",
            "org.bouncycastle:bcprov-jdk18on:1.77",
            "org.hamcrest:hamcrest-core:2.2",
            "org.robolectric:robolectric:4.14.1",
            "com.google.flogger:flogger:0.8",
            "com.google.flogger:flogger-system-backend:0.8",
            "com.google.guava:guava:32.1.2-jre",
            "com.google.guava:failureaccess:1.0.1",
            "info.picocli:picocli:4.7.4",
            "jakarta.inject:jakarta.inject-api:2.0.1",
            "junit:junit:4.13.2",
            "com.beust:jcommander:1.82",
            "com.google.protobuf:protobuf-java:4.31.1",
            "com.google.protobuf:protobuf-java-util:4.31.1",
            "com.google.code.findbugs:jsr305:3.0.2",
            "androidx.databinding:databinding-compiler:8.7.0",
            "org.ow2.asm:asm:9.6",
            "org.ow2.asm:asm-commons:9.6",
            "org.ow2.asm:asm-tree:9.6",
            "org.ow2.asm:asm-util:9.6",
            "com.android:zipflinger:8.7.0",
            "com.android.tools.build:gradle:8.7.0",
            "com.android:signflinger:8.7.0",
            "com.android.tools.build:aapt2-proto:8.6.1-11315950",
            "com.android.tools.build:apksig:8.7.0",
            "com.android.tools.build:apkzlib:8.7.0",
            "com.google.auto.value:auto-value:1.11.0",
            "com.google.auto.value:auto-value-annotations:1.11.0",
            "com.google.auto:auto-common:1.2.2",
            "com.google.auto.service:auto-service:1.1.1",
            "com.google.auto.service:auto-service-annotations:1.1.1",
            "com.google.errorprone:error_prone_annotations:2.33.0",
            "com.google.errorprone:error_prone_type_annotations:2.33.0",
            "com.google.errorprone:error_prone_check_api:2.33.0",
            "com.google.errorprone:error_prone_core:2.33.0",
            # Test deps
            "com.google.guava:guava-testlib:33.2.1-jre",
            "com.google.jimfs:jimfs:1.2",
            "com.google.testing.compile:compile-testing:0.18",
            "com.google.testparameterinjector:test-parameter-injector:1.16",
            "com.google.truth:truth:1.4.0",
            "com.google.truth.extensions:truth-java8-extension:1.4.0",
            "com.google.truth.extensions:truth-liteproto-extension:1.4.0",
            "com.google.truth.extensions:truth-proto-extension:1.4.0",
            "org.mockito:mockito-core:5.4.0",
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

    maven_install(
        # Specifically named since the worker API lib needs `@maven` to exist.
        # All lines in the artifacts list must be tagged "bazel worker api" for
        # the presubmit maven artifact consistency checker to pass.
        name = "maven",
        artifacts = [ # bazel worker api
            "com.google.code.gson:gson:2.10.1",  # bazel worker api
            "com.google.errorprone:error_prone_annotations:2.23.0",  # bazel worker api
            "com.google.guava:guava:33.0.0-jre",  # bazel worker api
            "com.google.protobuf:protobuf-java:4.27.2",  # bazel worker api
            "com.google.protobuf:protobuf-java-util:4.27.2",  # bazel worker api
            "junit:junit:4.13.2",  # bazel worker api
            "org.mockito:mockito-core:5.4.0",  # bazel worker api
            "com.google.truth:truth:1.4.0",  # bazel worker api
        ],  # bazel worker api
        aar_import_bzl_label = "@rules_android//rules:rules.bzl",
        repositories = [
            "https://repo1.maven.org/maven2",
            "https://maven.google.com",
        ],
    )
    go_rules_dependencies()

    _GO_TOOLCHAIN_VERSION = "1.22.4"
    go_download_sdk(name = "go_sdk", version = _GO_TOOLCHAIN_VERSION)
    go_register_toolchains()

    gazelle_dependencies()
    # gazelle:repository go_repository name=org_golang_x_xerrors importpath=golang.org/x/xerrors

    go_repository(
        name = "org_golang_google_protobuf",
        importpath = "google.golang.org/protobuf",
        sum = "h1:g0LDEJHgrBl9N9r17Ru3sqWhkIx2NB67okBHPwC7hs8=",
        version = "v1.31.0",
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

    go_repository(
        name = "org_bitbucket_creachadair_stringset",
        importpath = "bitbucket.org/creachadair/stringset",
        version = "v0.0.14",
        sum = "h1:t1ejQyf8utS4GZV/4fM+1gvYucggZkfhb+tMobDxYOE=",
    )

    robolectric_repositories()

    rules_proto_dependencies()
    rules_proto_toolchains()
    rules_proto_setup()

    py_repositories()

    python_register_toolchains(
        name = "python3_11",
        # Available versions are listed in @rules_python//python:versions.bzl.
        # We recommend using the same version your team is already standardized on.
        python_version = "3.11",
    )

    rules_shell_dependencies()
    rules_shell_toolchains()
