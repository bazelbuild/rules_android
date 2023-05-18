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

"""Bazel Android testing libs."""

load(
    ":file.bzl",
    _file = "file",
)
load(
    ":unittest.bzl",
    _analysistest = "analysistest",
    _unittest = "unittest",
)
load(
    "@bazel_skylib//lib:unittest.bzl",
    _asserts = "asserts",
)

file = _file

unittest = _unittest

analysistest = _analysistest

asserts = _asserts

def _failure_test_impl(ctx):
    env = analysistest.begin(ctx)
    if ctx.attr.expected_error_msg != "":
        asserts.expect_failure(env, ctx.attr.expected_error_msg)
    return analysistest.end(env)

failure_test = analysistest.make(
    _failure_test_impl,
    expect_failure = True,
    attrs = dict(
        expected_error_msg = attr.string(),
    ),
)
