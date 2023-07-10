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
"""Methods to process Android resources."""

load(":constants.bzl", "constants")
load(":utils.bzl", "utils")

# Android resource types, see https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/tools/aapt2/Resource.h
res_types = [
    "anim",
    "animator",
    "array",
    "attr",
    "^attr-private",
    "bool",
    "color",
    "configVarying",  #  Not really a type, but it shows up in some CTS tests
    "dimen",
    "drawable",
    "font",
    "fraction",
    "id",
    "integer",
    "interpolator",
    "layout",
    "macro",
    "menu",
    "mipmap",
    "navigation",
    "plurals",
    "raw",
    "string",
    "style",
    "styleable",
    "transition",
    "xml",
]

def get_assets_dir(asset, base_dir):
    """Build the full assets directory sanitizing the input first."""
    if base_dir == "":
        # some targets specify assets files and set assets_dirs = ""
        return asset.dirname
    asset_path = asset.path.rstrip("/")
    base_dir = base_dir.rstrip("/")
    if asset_path.endswith("/" + base_dir):
        return asset_path
    return "%s/%s" % (asset_path.rpartition("/%s/" % base_dir)[0], base_dir)

def compile_resources(ctx, lib_strategy = True):
    """Compiles android resources using aapt2

    Args:
      ctx: The context.
      lib_strategy: If to use library strategy or bucket. Default is lib strategy.

    Returns:
      A list of compiled android resource archives (.flata) files, otherwise None
      if data is None or empty.
    """
    res_dir_file_map = partition_by_res_dirs(ctx.rule.files.resource_files)
    if lib_strategy:
        return _compile_library_resouces(ctx, res_dir_file_map)
    res_dir_buckets_map = _bucketize_resources(ctx, res_dir_file_map)
    return _compile_bucketized_resources(ctx, res_dir_buckets_map)

def partition_by_res_dirs(res_files):
    """Partitions the resources by res directories.

    Args:
      res_files: A list of resource artifacts files.

    Returns:
      A map of "res" directories to files corresponding to the directory.
    """
    if not res_files:
        return None

    # Given the fact that res directories can be named anything and
    # its not possible to distinguish between directories and regular files
    # during analysis time, we use file extensions as an heuristic to group
    # resource files. All Android resource files have the following form
    # res-dir/type-dir/res_file. When we see a regular file (by looking at
    # the extesion) we use the directory two levels up as the grouping dir.
    # Most of the resource directories will contain at least one file with
    # and extension, so this heuristic will generally result in good groupings.
    res_non_values_file_map = {}
    res_value_file_map = {}
    res_dir_map = {}
    for res_file in res_files:
        if res_file.is_directory:
            res_dir_map.setdefault(res_file.path, []).append(res_file)
        else:
            path_segments = res_file.dirname.rsplit("/", 1)
            root_dir = path_segments[0]
            if path_segments[1].startswith("values"):
                res_value_file_map.setdefault(root_dir, []).append(res_file)
            else:
                res_non_values_file_map.setdefault(root_dir, []).append(res_file)
    return {
        "values": res_value_file_map,
        "non-values": res_non_values_file_map,
        "res_dir": res_dir_map,
    }

def _bucketize_resources(ctx, data):
    """Bucketizes resources by type.

    Args:
      ctx: The context.
      data: A map of "res" directories to files corresponding to the directory.

    Returns:
      A map of "res" directories to "res" buckets, None when there no resource
      files to compile.
    """
    if not data:
        return None

    # Create backing files for the resource sharder.
    res_dir_buckets_map = {}
    for i, res_dir in enumerate(data.keys()):
        res_buckets = []
        typed_outputs = []

        for r_type in res_types:
            for idx in range(ctx.attr._mi_res_shards):
                res_bucket = utils.isolated_declare_file(
                    ctx,
                    ctx.label.name + "_mi/resources/buckets/%d/%s_%s.zip" % (i, r_type, idx),
                )
                res_buckets.append(res_bucket)
                typed_outputs.append(r_type + ":" + res_bucket.path)

        args = ctx.actions.args()
        args.use_param_file(param_file_arg = "-flagfile=%s")
        args.set_param_file_format("multiline")
        args.add_joined("-typed_outputs", typed_outputs, join_with = ",")
        if data[res_dir]:
            args.add_joined("-res_paths", data[res_dir], join_with = ",")

        ctx.actions.run(
            executable = ctx.executable._android_kit,
            arguments = ["bucketize", args],
            inputs = data[res_dir],
            outputs = res_buckets,
            mnemonic = "BucketizeRes",
            progress_message = "MI Bucketize resources for %s" % res_dir,
        )
        res_dir_buckets_map[res_dir] = res_buckets
    return res_dir_buckets_map

def _compile_bucketized_resources(ctx, data):
    """Compiles android resources using aapt2

    Args:
      ctx: The context.
      data: A map of res directories to resource buckets.

    Returns:
      A list of compiled android resource archives (.flata) files, otherwise None
      if data is None or empty.
    """
    if not data:
        return constants.EMPTY_LIST

    # TODO(mauriciogg): use no-crunch. We are using crunch to process 9-patch
    # pngs should be disabled in general either by having a more granular flag
    # in aapt2 or bucketizing 9patch pngs. See (b/70578281)
    compiled_res_buckets = []
    for res_dir, res_buckets in data.items():
        for res_bucket in res_buckets:
            # Note that extension matters for aapt2.
            out = utils.isolated_declare_file(
                ctx,
                res_bucket.basename + ".flata",
                sibling = res_bucket,
            )
            ctx.actions.run(
                executable = ctx.executable._android_kit,
                arguments = [
                    "compile",
                    "--aapt2=" + utils.first(ctx.attr._aapt2.files).path,
                    "--in=" + res_bucket.path,
                    "--out=" + out.path,
                ],
                inputs = [res_bucket] + ctx.attr._aapt2.files.to_list(),
                outputs = [out],
                mnemonic = "CompileRes",
                progress_message = "MI Compiling resources for %s" % res_dir,
            )
            compiled_res_buckets.append(out)

    return compiled_res_buckets

def _compile_library_resouces(ctx, data):
    """Compiles android resources using aapt2

    Args:
      ctx: The context.
      data: A map of res directories to resource buckets.

    Returns:
      A list of compiled android resource archives (.flata) files, otherwise None
      if data is None or empty.
    """
    if not data:
        return constants.EMPTY_LIST

    # TODO(mauriciogg): use no-crunch. We are using crunch to process 9-patch
    # pngs should be disabled in general either by having a more granular flag
    # in aapt2 or bucketizing 9patch pngs. See (b/70578281)
    compiled_res_dirs = []
    for res_type in data.keys():
        for res_dir in data[res_type].keys():
            # Note that extension matters for aapt2.
            out = utils.isolated_declare_file(
                ctx,
                ctx.label.name + "_mi/resources/%s_%s.flata" % (res_dir.replace("/", "_"), res_type),
            )
            compiled_res_dirs.append(out)

            args = ctx.actions.args()
            args.use_param_file(param_file_arg = "--flagfile=%s", use_always = True)
            args.set_param_file_format("multiline")
            args.add("-aapt2", ctx.file._aapt2)
            args.add("-in", res_dir)
            args.add("-out", out)
            ctx.actions.run(
                executable = ctx.executable._android_kit,
                arguments = ["compile", args],
                inputs = data[res_type][res_dir] + ctx.attr._aapt2.files.to_list(),
                outputs = [out],
                mnemonic = "CompileRes",
                progress_message = "MI Compiling resources for %s" % res_dir,
            )
    return compiled_res_dirs

def link_resources(
        ctx,
        manifest,
        java_package,
        android_jar,
        resource_archives,
        assets,
        assets_dirs):
    """Links android resources using aapt2

    Args:
      ctx: The context.
      manifest: The AndroidManifest.xml file
      java_package: The package to use to generate R.java
      android_jar: The android jar
      resource_archives: List of intermediate compiled android resource files.
      assets: The list of assets.
      assets_dirs: The list of directories for the assets.

    Returns:
      The resource apk and the R java file generated by aapt2.
    """
    if not resource_archives:
        return None

    resource_apk = utils.isolated_declare_file(ctx, ctx.label.name + "_mi/resources/resource.apk")
    rjava_zip = utils.isolated_declare_file(ctx, "R.zip", sibling = resource_apk)

    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "-flagfile=%s", use_always = True)
    args.add("-aapt2", ctx.executable._aapt2)
    args.add("-sdk_jar", android_jar)
    args.add("-manifest", manifest)
    args.add("-pkg", java_package)
    args.add("-src_jar", rjava_zip)
    args.add("-out", resource_apk)
    args.add_joined("-res_dirs", resource_archives, join_with = ",")
    args.add_joined("-asset_dirs", assets_dirs, join_with = ",")

    ctx.actions.run(
        executable = ctx.executable._android_kit,
        arguments = ["link", args],
        inputs = depset(
            [manifest, android_jar, ctx.executable._aapt2] + resource_archives,
            transitive = [assets],
        ),
        outputs = [resource_apk, rjava_zip],
        mnemonic = "LinkRes",
        progress_message = "MI Linking resources for %s" % ctx.label,
    )
    return resource_apk, rjava_zip

def liteparse(ctx):
    """Creates an R.pb which contains the resource ids gotten from a light parse.

    Args:
      ctx: The context.

    Returns:
      The resource pb file object.
    """
    if not hasattr(ctx.rule.files, "resource_files"):
        return None

    r_pb = utils.isolated_declare_file(ctx, ctx.label.name + "_mi/resources/R.pb")

    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "--flagfile=%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add_joined("--res_files", ctx.rule.files.resource_files, join_with = ",")
    args.add("--out", r_pb)

    ctx.actions.run(
        executable = ctx.executable._android_kit,
        arguments = ["liteparse", args],
        inputs = ctx.rule.files.resource_files,
        outputs = [r_pb],
        mnemonic = "ResLiteParse",
        progress_message = "MI Lite parse Android Resources %s" % ctx.label,
    )
    return r_pb

def compiletime_r_srcjar(ctx, output_srcjar, r_pbs, package):
    """Create R.srcjar from the given R.pb files in the transitive closure.

    Args:
      ctx: The context.
      output_srcjar: The output R source jar artifact.
      r_pbs: Transitive  set of resource pbs.
      package: The package name of the compile-time R.java.
    """
    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "--flagfile=%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add("-rJavaOutput", output_srcjar)
    args.add("-packageForR", package)
    args.add_joined("-resourcePbs", r_pbs, join_with = ",")

    ctx.actions.run(
        executable = ctx.executable._android_kit,
        arguments = ["rstub", args],
        inputs = r_pbs,
        outputs = [output_srcjar],
        mnemonic = "CompileTimeRSrcjar",
        progress_message = "MI Make compile-time R.srcjar %s" % ctx.label,
    )
