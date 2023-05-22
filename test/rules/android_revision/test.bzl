# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Bazel rules that test the Android revision parsing.

The following are test rules that can be used to test the AndroidRevisionInfo provider.

android_revision_test: Inspect providers with the given set of expected values.
"""

load(
    "//rules:android_revision.bzl",
    "compare_android_revisions",
    "parse_android_revision",
)
load(
    "//test/utils:lib.bzl",
    "asserts",
    "unittest",
)

def _android_revision_test_impl(ctx):
    env = unittest.begin(ctx)
    input = ctx.attr.input
    revision = parse_android_revision(input)

    asserts.equals(
        env,
        ctx.attr.expected_major,
        revision.major,
    )
    asserts.equals(
        env,
        ctx.attr.expected_minor,
        revision.minor,
    )
    asserts.equals(
        env,
        ctx.attr.expected_micro,
        revision.micro,
    )
    asserts.equals(
        env,
        ctx.attr.expected_version,
        revision.version,
    )
    asserts.equals(
        env,
        ctx.attr.expected_dir,
        revision.dir,
    )

    return unittest.end(env)

android_revision_test = unittest.make(
    impl = _android_revision_test_impl,
    attrs = {
        "input": attr.string(),
        "expected_major": attr.int(),
        "expected_minor": attr.int(),
        "expected_micro": attr.int(),
        "expected_version": attr.string(),
        "expected_dir": attr.string(),
    },
)

def _assert_revisions_equal(env, expected, value):
    asserts.equals(env, expected.major, value.major)
    asserts.equals(env, expected.minor, value.minor)
    asserts.equals(env, expected.major, value.major)

def _android_revision_comparision_test_impl(ctx):
    env = unittest.begin(ctx)
    higher = parse_android_revision(ctx.attr.higher)
    lower = parse_android_revision(ctx.attr.lower)

    result = compare_android_revisions(higher, lower)
    _assert_revisions_equal(
        env,
        higher,
        result,
    )

    return unittest.end(env)

android_revision_comparision_test = unittest.make(
    impl = _android_revision_comparision_test_impl,
    attrs = {
        "higher": attr.string(),
        "lower": attr.string(),
    },
)
