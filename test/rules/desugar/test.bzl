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
"""Tests for Desugar worker execution requirements."""

load("//flags:flags_wrapper.bzl", "WrappedFlagsInfo")
load("//rules:desugar.bzl", "desugar")
load("//test/utils:lib.bzl", "analysistest", "asserts")

_DesugarActionInfo = provider(
    doc = "Records the Desugar execution requirements.",
    fields = ["execution_requirements"],
)

def _desugar_action_impl(ctx):
    input = ctx.actions.declare_file(ctx.label.name + ".jar")
    output = ctx.actions.declare_file(ctx.label.name + "_desugared.jar")
    config = ctx.actions.declare_file(ctx.label.name + ".json")
    tool = ctx.actions.declare_file(ctx.label.name + "_tool.sh")
    ctx.actions.write(input, "")
    ctx.actions.write(config, "{}")
    ctx.actions.write(tool, "#!/bin/sh\nexit 0\n", is_executable = True)

    # Capture the action arguments. Bazel does not expose execution requirements to analysis tests.
    action = {}
    desugar_ctx = struct(
        actions = struct(args = ctx.actions.args, run = action.update),
        attr = struct(_wrapped_flags = {WrappedFlagsInfo: WrappedFlagsInfo(flags = {
            "internal_persistent_android_dex_desugar": struct(value = ctx.attr.workers),
            "internal_persistent_multiplex_android_dex_desugar": struct(value = ctx.attr.multiplex),
        })}),
        fragments = struct(android = struct(
            persistent_android_dex_desugar = ctx.attr.workers,
            persistent_multiplex_android_dex_desugar = ctx.attr.multiplex,
        )),
    )
    desugar.desugar(
        desugar_ctx,
        input = input,
        output = output,
        classpath = depset(),
        library_desugaring = False,
        desugar_exec = tool,
        desugared_lib_config = config,
    )
    ctx.actions.run(**action)
    return [
        DefaultInfo(files = depset([output])),
        _DesugarActionInfo(execution_requirements = action["execution_requirements"]),
    ]

_desugar_action = rule(
    implementation = _desugar_action_impl,
    attrs = {
        "workers": attr.bool(),
        "multiplex": attr.bool(),
    },
)

def _worker_requirements_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = [a for a in analysistest.target_actions(env) if a.mnemonic == "Desugar"]
    asserts.equals(env, 1, len(actions))
    target = analysistest.target_under_test(env)
    asserts.equals(env, ctx.attr.expected_requirements, target[_DesugarActionInfo].execution_requirements)
    return analysistest.end(env)

_worker_requirements_test = analysistest.make(
    impl = _worker_requirements_test_impl,
    attrs = {"expected_requirements": attr.string_dict()},
)

def desugar_worker_test_suite(name):
    """Tests all worker flag combinations for a Desugar action.

    Args:
        name: The test suite name.
    """
    requirements = {"supports-path-mapping": "1"}
    tests = []
    for suffix, workers, multiplex, expected in [
        ("disabled", False, False, requirements),
        ("singleplex", True, False, dict(requirements, **{"supports-workers": "1"})),
        ("multiplex", True, True, dict(requirements, **{
            "supports-workers": "1",
            "supports-multiplex-workers": "1",
        })),
        ("multiplex_without_workers", False, True, requirements),
    ]:
        test_name = name + "_" + suffix + "_test"
        target = name + "_" + suffix + "_target"
        _desugar_action(name = target, workers = workers, multiplex = multiplex, tags = ["manual"])
        _worker_requirements_test(
            name = test_name,
            target_under_test = ":" + target,
            expected_requirements = expected,
        )
        tests.append(test_name)
    native.test_suite(name = name, tests = tests)
