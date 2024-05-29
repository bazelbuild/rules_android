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
"""Methods to create and process R.java."""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@rules_java//java/common:java_common.bzl", "java_common")
load(":utils.bzl", "utils")

visibility(PROJECT_VISIBILITY)

def _make_r_java(ctx, resource_src_jar, main_r_java, out_r_java):
    """Remove final qualifieres from R.java."""

    # R classes used during library compilation have only library level
    # information about app resources, therefore we strip those files but still
    # need to repackage the final version of the R classes for all packages.
    # In theory we could implement this as a provider in blaze and use whatever
    # they create, however their implementation might be suboptimal.
    cmd = """
if [[ $1 == *.java ]]; then
  r_java=$1
else
  r_java_dir=$(mktemp -d)
  r_java="${r_java_dir}/R.java"
  unzip -j -q $1 $2 -d "${r_java_dir}" &> /dev/null
fi
# R jar might be empty, so check for R java file explicitly
if [[ -f ${r_java} ]]; then
  sed -i -e 's/final class/class/g' ${r_java}
  cat ${r_java} | grep -v "^package .*;$" > $3
else
  touch $3
fi
"""
    ctx.actions.run_shell(
        command = cmd,
        arguments = [
            resource_src_jar.path,
            main_r_java,
            out_r_java.path,
        ],
        inputs = [resource_src_jar],
        outputs = [out_r_java],
        mnemonic = "MakeRJava",
        progress_message = "MI R.java " + out_r_java.path,
    )

def _make_r_jar(ctx, r_java, packages, out_r_jar):
    """Makes an R.jar containing all the Rs for the app."""

    # TODO(djwhang): Create an intermediary action that creates the remaining
    # R.java files and then use the default compiler to compile and Jar.
    r_packages = utils.isolated_declare_file(
        ctx,
        "r_packages.txt",
        sibling = out_r_jar,
    )
    ctx.actions.write(
        output = r_packages,
        content = "\n".join(packages.to_list()),
    )

    rjar_args = ctx.actions.args()
    rjar_args.add("rjar")
    rjar_args.add("--jdk", utils.host_jvm_path(ctx))
    rjar_args.add("--jartool", utils.first(ctx.attr._jar_tool[DefaultInfo].files.to_list()).path)
    rjar_args.add("--rjava", r_java.path)
    rjar_args.add("--pkgs", r_packages.path)
    rjar_args.add("--rjar", out_r_jar.path)
    rjar_args.add("--target_label", str(ctx.label))
    rjar_args.add_joined("--jvm_opts", ctx.attr._java_toolchain[java_common.JavaToolchainInfo].jvm_opt, join_with = " ")

    # Call action binary.
    ctx.actions.run(
        executable = ctx.executable._android_kit,
        arguments = [rjar_args],
        tools = ctx.attr._jar_tool[DefaultInfo].files,
        inputs = depset([r_packages, r_java], transitive = [ctx.attr._java_jdk[DefaultInfo].files]),
        outputs = [out_r_jar],
        mnemonic = "RJar",
        progress_message = "MI RJar " + out_r_jar.path,
    )

def make_r(ctx, r_java_zip, main_package, packages, sibling):
    """Creates all the Rs for the app then compiles, Jar and Dex it.

    Args:
      ctx: The context.
      r_java_zip: A zip file containing the main R.java file.
      main_package: A string representing the package of the main target.
      packages: The list of packages in the app that need Rs.
      sibling: The file used as the relative location for any new files created.

    Returns:
      The R.java as a Dex file.
    """
    main_r_java = main_package.replace(".", "/") + "/R.java"
    r_java = utils.isolated_declare_file(ctx, "dex_shards/R.java", sibling = sibling)
    _make_r_java(ctx, r_java_zip, main_r_java, r_java)

    r_jar = utils.isolated_declare_file(ctx, "R.jar", sibling = r_java)
    _make_r_jar(ctx, r_java, packages, r_jar)

    # To ensure R.zip is at the beginning of all the dex_shards,which ranges
    # between 01-16, the R.zip is named as 00.zip
    r_dex = utils.isolated_declare_file(ctx, "00.zip", sibling = r_java)
    utils.merge_dex_shards(ctx, [r_jar], r_dex)
    return r_dex
