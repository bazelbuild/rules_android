# Copyright 2024 The Bazel Authors. All rights reserved.
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

"""Rule definitions to create Java 11 compilation targets for javac's --system flag."""

load("@rules_java//java:defs.bzl", "java_common")
load("//rules:java.bzl", _java = "java")

def _single_jar(ctx, inputs, output):
    _java.singlejar(
        ctx,
        inputs = inputs,
        output = output,
        java_toolchain = ctx.attr._java_toolchain,
    )

def _ijar(ctx, input, output):
    args = ctx.actions.args()
    args.add(input)
    args.add(output)
    args.add("--target_label", ctx.label)
    ijar_bin = ctx.attr._java_toolchain[java_common.JavaToolchainInfo].ijar
    ctx.actions.run(
        inputs = [input],
        outputs = [output],
        executable = ijar_bin,
        arguments = [args],
        progress_message = "Extracting interfaces from %s" % input.short_path,
        mnemonic = "Ijar",
    )

def _android_system(ctx):
    bootclasspath = ctx.files.bootclasspath

    merged_unannotated_jar = ctx.actions.declare_file("%s_merged_unannotated.jar" % ctx.label.name)
    _single_jar(ctx, bootclasspath, merged_unannotated_jar)

    merged_jar = merged_unannotated_jar

    merged_interface_jar = ctx.actions.declare_file("%s_merged_interface.jar" % ctx.label.name)
    _ijar(ctx, merged_jar, merged_interface_jar)

    core_jars = ctx.files.core_jars

    core_jar = ctx.actions.declare_file("%s_core.jar" % ctx.label.name)
    auxiliary_jar = ctx.actions.declare_file("%s_auxiliary_full.jar" % ctx.label.name)
    auxiliary_interface_jar = ctx.actions.declare_file("%s_auxiliary.jar" % ctx.label.name)
    _ijar(ctx, auxiliary_jar, auxiliary_interface_jar)

    args = ctx.actions.args()
    args.add("--input", merged_interface_jar)
    args.add_joined("--core_jars", core_jars, join_with = ",")
    args.add("--output_core_jar", core_jar)
    args.add("--output_auxiliary_jar", auxiliary_jar)
    args.add_joined("--exclusions", ctx.attr.exclusions, join_with = ",")
    ctx.actions.run(
        mnemonic = "SplitCoreJar",
        inputs = [merged_interface_jar] + core_jars,
        outputs = [core_jar, auxiliary_jar],
        arguments = [args],
        executable = ctx.executable._split_core_jar,
    )

    module_info = ctx.actions.declare_file("%s/module-info.java" % ctx.label.name)
    args = ctx.actions.args()
    args.add("--input", core_jar)
    args.add("--output", module_info)
    ctx.actions.run(
        mnemonic = "JarToModuleInfo",
        inputs = [core_jar],
        outputs = [module_info],
        arguments = [args],
        executable = ctx.executable._jar_to_module_info,
    )

    system = ctx.actions.declare_directory("%s_system" % ctx.label.name)
    java_runtime = ctx.attr._runtime[java_common.JavaRuntimeInfo]
    args = ctx.actions.args()
    args.add("--input", core_jar)
    args.add("--output", system.path)
    args.add("--unzip", ctx.executable._unzip)
    args.add("--java_home", java_runtime.java_home)
    args.add("--module_info", module_info)
    ctx.actions.run(
        inputs = depset(
            [
                core_jar,
                module_info,
            ],
            transitive = [java_runtime.files],
        ),
        tools = [ctx.executable._unzip],
        outputs = [system],
        arguments = [args],
        executable = ctx.executable.create_system,
        mnemonic = "CreateSystem",
    )

    files = [merged_interface_jar, system, auxiliary_interface_jar]
    return [
        java_common.BootClassPathInfo(
            system = system,
            auxiliary = [auxiliary_interface_jar],
            bootclasspath = [merged_interface_jar],
        ),
        DefaultInfo(
            files = depset(files),
            runfiles = ctx.runfiles(files),
        ),
    ]

android_system = rule(
    implementation = _android_system,
    doc = "Creates a system directory for targeting the default android.jar.",
    attrs = {
        "_java_toolchain": attr.label(
            default = Label("//tools/jdk:current_java_toolchain"),
        ),
        "_unzip": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//tools/android:unzip"),
            allow_files = True,
        ),
        "_jar_to_module_info": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//src/tools/jar_to_module_info"),
            allow_files = True,
        ),
        "create_system": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//tools/jdk:create_system"),
            allow_files = True,
        ),
        "_split_core_jar": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//src/tools/split_core_jar"),
            allow_files = True,
        ),
        "_runtime": attr.label(
            default = Label("//tools/jdk:current_java_runtime"),
            cfg = "exec",
            providers = [java_common.JavaRuntimeInfo],
        ),
        "bootclasspath": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "core_jars": attr.label_list(
            cfg = "target",
            allow_files = True,
        ),
        "exclusions": attr.string_list(),
        "overlay_jar": attr.label(
            cfg = "exec",
            allow_single_file = True,
            executable = False,
        ),
        # TODO(b/281980093): No matching toolchains found for types //tools/jdk:runtime_toolchain_type.
        "_use_auto_exec_groups": attr.bool(default = False),
    },
)
