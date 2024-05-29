# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""A rule that returns android.jar from the current android sdk."""

load("//rules:common.bzl", _common = "common")
load("//rules:java.bzl", _java = "java")
load("//rules:utils.bzl", "ANDROID_SDK_TOOLCHAIN_TYPE", "get_android_sdk")

def _android_jar_impl(ctx):
    return DefaultInfo(
        files = depset([get_android_sdk(ctx).android_jar]),
    )

android_jar = rule(
    implementation = _android_jar_impl,
    attrs = {
        "_sdk": attr.label(
            allow_rules = ["android_sdk"],
            default = configuration_field(
                fragment = "android",
                name = "android_sdk_label",
            ),
            providers = [AndroidSdkInfo],
        ),
    },
    toolchains = [
        ANDROID_SDK_TOOLCHAIN_TYPE,
    ],
)

def _run_singlejar_impl(ctx):
    _java.singlejar(
        ctx,
        inputs = ctx.files.srcs,
        output = ctx.outputs.out,
        include_prefixes = ctx.attr.include_prefixes,
        java_toolchain = _common.get_java_toolchain(ctx),
    )

run_singlejar = rule(
    implementation = _run_singlejar_impl,
    doc = "Runs singlejar over the given files.",
    attrs = {
        "srcs": attr.label_list(mandatory = True),
        "out": attr.output(mandatory = True),
        "include_prefixes": attr.string_list(),
        "_java_toolchain": attr.label(default = Label("//tools/jdk:toolchain")),
    },
)

def _run_ijar(ctx):
    ijar_jar = java_common.run_ijar(
        ctx.actions,
        jar = ctx.file.jar,
        java_toolchain = ctx.attr._java_toolchain[java_common.JavaToolchainInfo],
    )
    return [DefaultInfo(files = depset([ijar_jar]))]

run_ijar = rule(
    implementation = _run_ijar,
    doc = "Runs ijar over the given jar.",
    attrs = {
        "jar": attr.label(mandatory = True, allow_single_file = True),
        "_java_toolchain": attr.label(
            default = "//tools/jdk:current_java_toolchain",
            providers = [java_common.JavaToolchainInfo],
        ),
    },
    toolchains = ["@bazel_tools//tools/jdk:toolchain_type"],
)
