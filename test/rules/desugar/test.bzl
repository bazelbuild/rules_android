# Copyright 2026 The Bazel Authors. All rights reserved.
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
"""Tests for desugar.bzl."""

load("//rules:desugar.bzl", "desugar")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//test/utils:lib.bzl", "analysistest", "asserts")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")

visibility(PROJECT_VISIBILITY)

def _contains_all(classpath, jars):
    return all([jar in classpath for jar in jars])

def _contains_any(classpath, jars):
    return any([jar in classpath for jar in jars])

def _classpath_test_impl(ctx):
    env = analysistest.begin(ctx)
    java_info = analysistest.target_under_test(env)[JavaInfo]
    dep_header_jars = ctx.attr.dep[JavaInfo].compile_jars.to_list()
    dep_full_jars = ctx.attr.dep[JavaInfo].full_compile_jars.to_list()

    full_classpath = desugar.get_classpath(java_info).to_list()
    asserts.true(env, _contains_all(full_classpath, dep_full_jars))
    asserts.false(env, _contains_any(full_classpath, dep_header_jars))

    header_classpath = desugar.get_classpath(java_info, use_header_jars = True).to_list()
    asserts.true(env, _contains_all(header_classpath, dep_header_jars))
    asserts.false(env, _contains_any(header_classpath, dep_full_jars))

    return analysistest.end(env)

classpath_test = analysistest.make(
    _classpath_test_impl,
    attrs = {
        "dep": attr.label(providers = [JavaInfo]),
    },
)
