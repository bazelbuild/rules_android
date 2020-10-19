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
    "@rules_android//rules:attrs.bzl",
    _attrs = "attrs",
)

ATTRS = _attrs.add(
    dict(
        aar = attr.label(
            allow_single_file = [".aar"],
            mandatory = True,
        ),
        data = attr.label_list(allow_files = True),
        deps = attr.label_list(
            allow_files = False,
            providers = [JavaInfo],
        ),
        exports = attr.label_list(
            allow_files = False,
            allow_rules = ["aar_import", "java_import"],
        ),
        srcjar = attr.label(
            allow_single_file = [".srcjar"],
            doc =
                "A srcjar file that contains the source code for the JVM " +
                "artifacts stored within the AAR.",
        ),
        _flags = attr.label(
            default = "@rules_android//rules/flags",
        ),
        _diff_test_validation_stub_script = attr.label(
            cfg = "host",
            default = "@rules_android//test/rules/resources:test_stub_script.sh",
            allow_single_file = True,
        ),
        _java_toolchain = attr.label(
            default = Label("//tools/jdk:toolchain_android_only"),
        ),
        _host_javabase = attr.label(
            cfg = "host",
            default = Label("//tools/jdk:current_java_runtime"),
        ),
    ),
    _attrs.DATA_CONTEXT,
)
