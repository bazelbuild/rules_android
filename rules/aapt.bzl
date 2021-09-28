# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Bazel AAPT Commands."""

def _link(
        ctx,
        out_r_java,
        out_resource_apk,
        manifest = None,
        java_package = None,
        assets = depset([]),
        assets_dirs = [],
        compiled_resources = depset([]),
        config_filters = [],
        make_r_java_ids_non_final = False,
        compatible_with_resource_shrinking = True,
        enable_debug = False,
        enable_static_lib = False,
        android_jar = None,
        aapt = None):
    """Links compiled Android Resources with AAPT.

    Args:
      ctx: The context.
      out_r_java: A File. The R.java outputted by linking resources.
      out_resource_apk: A File. The Resource APK outputted by linking resources.
      manifest: A File. The AndroidManifest.xml.
      java_package: A string. The Java package for the generated R.java.
      assets: A list of Files. The list of assets from the transitive closure of
        the project.
      assets_dirs: A list of strings. The list of asset directories in the
        transitive closure of the project.
      compiled_resources: List of intermediate compiled android resource files.
      config_filters: A list of Strings. The configuration filters.
      make_r_java_ids_non_final: A bool. Makes the R.java produced from linkin
        have non-final values.
      compatible_with_resource_shrinking: A bool. When enabled produces the
        output in proto format which is a requirement for resource shrinking.
      enable_debug: A bool. Enable debugging
      enable_static_lib: A bool. Enable static lib.
      android_jar: A File. The Android Jar.
      aapt: A FilesToRunProvider. The AAPT executable.
    """

    # Output the list of resources in reverse topological order.
    resources_param = ctx.actions.declare_file(
        out_r_java.basename + ".params",
        sibling = out_r_java,
    )
    args = ctx.actions.args()
    args.use_param_file("%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add_all(compiled_resources, expand_directories = True)
    ctx.actions.run_shell(
        command = """
# Reverses the set of inputs that have been topologically ordered to utilize the
# overlay/override semantics of aapt2.
set -e

echo $(tac $1) > $2
""",
        arguments = [args, resources_param.path],
        outputs = [resources_param],
        inputs = compiled_resources,
    )

    args = ctx.actions.args()
    args.add("link")
    if enable_static_lib:
        args.add("--static-lib")
    args.add("--no-version-vectors")
    args.add("--no-static-lib-packages")  # Turn off namespaced resource

    args.add("--manifest", manifest)
    args.add("--auto-add-overlay")  # Enables resource redefinition and merging
    args.add("--override-styles-instead-of-overlaying")  # mimic AAPT1.
    if make_r_java_ids_non_final:
        args.add("--non-final-ids")
    if compatible_with_resource_shrinking:
        args.add("--proto-format")
    if enable_debug:
        args.add("--debug-mode")
    args.add("--custom-package", java_package)
    args.add("-I", android_jar)
    args.add_all(assets_dirs, before_each = "-A")
    args.add("-R", resources_param, format = "@%s")
    args.add("-0", ".apk")
    args.add_joined("-c", config_filters, join_with = ",", omit_if_empty = True)
    args.add("--java", out_r_java.path.rpartition(java_package.replace(".", "/"))[0])
    args.add("-o", out_resource_apk)

    ctx.actions.run(
        executable = aapt,
        arguments = [args],
        inputs = depset(
            [android_jar, resources_param] +
            ([manifest] if manifest else []),
            transitive = [assets, compiled_resources],
        ),
        outputs = [out_resource_apk, out_r_java],
        mnemonic = "LinkAndroidResources",
        progress_message = "ResV3 Linking Android Resources to %s" % out_resource_apk.short_path,
    )

def _compile(
        ctx,
        out_dir,
        resource_files,
        aapt):
    """Compile and store resources in a single archive.

    Args:
      ctx: The context.
      out_dir: File. A file to store the output.
      resource_files: A list of Files. The list of resource files or directories
        to process.
      aapt: AAPT. Tool for compiling resources.
    """
    if not out_dir:
        fail("No output directory specified.")
    if not out_dir.is_directory:
        fail("Output directory is not a directory artifact.")
    if not resource_files:
        fail("No resource files given.")

    # Retrieves the list of files at runtime when a directory is passed.
    args = ctx.actions.args()
    args.add_all(resource_files, expand_directories = True)

    ctx.actions.run_shell(
        command = """
set -e

AAPT=%s
OUT_DIR=%s
RESOURCE_FILES=$@

i=0
declare -A out_dir_map
for f in ${RESOURCE_FILES}; do
  res_dir="$(dirname $(dirname ${f}))"
  if [ -z "${out_dir_map[${res_dir}]}" ]; then
      out_dir="${OUT_DIR}/$((++i))"
      mkdir -p ${out_dir}
      out_dir_map[${res_dir}]="${out_dir}"
  fi
  # Outputs from multiple directories can overwrite the outputs. As we do not
  # control the outputs for now store each in its own sub directory which will be
  # captured by the over_dir.
  # TODO(b/139757260): Re-evaluate this one compile per file or multiple and zip
  # merge.
  "${AAPT}" compile --legacy "${f}" -o "${out_dir_map[${res_dir}]}"
done
""" % (aapt.executable.path, out_dir.path),
        tools = [aapt],
        arguments = [args],
        inputs = resource_files,
        outputs = [out_dir],
        mnemonic = "CompileAndroidResources",
        progress_message = "ResV3 Compiling Android Resources in %s" % out_dir,
    )

def _convert(
        ctx,
        out = None,
        input = None,
        to_proto = False,
        aapt = None):
    args = ctx.actions.args()
    args.add("convert")
    args.add("--output-format", ("proto" if to_proto else "binary"))
    args.add("-o", out)
    args.add(input)

    ctx.actions.run(
        executable = aapt,
        arguments = [args],
        inputs = [input],
        outputs = [out],
        mnemonic = "AaptConvert",
        progress_message = "ResV3 Convert to %s" % out.short_path,
    )

aapt = struct(
    link = _link,
    compile = _compile,
    convert = _convert,
)
