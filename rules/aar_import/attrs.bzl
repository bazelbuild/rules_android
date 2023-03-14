# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""Attributes."""

load(
    "//rules:attrs.bzl",
    _attrs = "attrs",
)

ATTRS = _attrs.add(
    dict(
        aar = attr.label(
            allow_single_file = [".aar"],
            mandatory = True,
            doc = "The .aar file to process.",
        ),
        data = attr.label_list(
            allow_files = True,
            doc = "Files needed by this rule at runtime. May list file or rule " +
                  "targets. Generally allows any target.",
        ),
        deps = attr.label_list(
            allow_files = False,
            providers = [JavaInfo],
            doc = "The list of libraries to link against.",
        ),
        exports = attr.label_list(
            allow_files = False,
            allow_rules = ["aar_import", "java_import", "kt_jvm_import"],
            doc = "The closure of all rules reached via `exports` attributes are considered " +
                  "direct dependencies of any rule that directly depends on the target with " +
                  "`exports`. The `exports` are not direct deps of the rule they belong to.",
        ),
        has_lint_jar = attr.bool(
            default = False,
            doc = "Whether the aar contains a lint.jar. This is required to " +
                  "know at analysis time if a lint jar is included in the aar.",
        ),
        package = attr.string(
            doc = "Package to use while processing the aar at analysis time. " +
                  "This needs to be the same value as the manifest's package.",
        ),
        srcjar = attr.label(
            allow_single_file = [".srcjar"],
            doc = "A srcjar file that contains the source code for the JVM " +
                  "artifacts stored within the AAR.",
        ),
        _flags = attr.label(
            default = "//rules/flags",
        ),
        _java_toolchain = attr.label(
            default = Label("//tools/jdk:toolchain_android_only"),
        ),
        _host_javabase = attr.label(
            cfg = "exec",
            default = Label("//tools/jdk:current_java_runtime"),
        ),
    ),
    _attrs.DATA_CONTEXT,
    _attrs.ANDROID_TOOLCHAIN_ATTRS,
)
