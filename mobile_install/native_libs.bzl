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
"Creates the zip with the app native libraries."

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":utils.bzl", "utils")

visibility(PROJECT_VISIBILITY)

def make_native_zips(ctx, native_libs, aar_native_libs, sibling):
    """Creates zip files containing all of the application native libraries.

    Each zip has all of the native libraries for a single CPU architecture.

    Args:
        ctx: The aspect context.
        native_libs: A dictionary of depsets of native libraries, keyed by CPU architecture.
        aar_native_libs: A dictionary of depsets of native libraries from aar_import targets, keyed by CPU architecture.
        sibling: Used to ensure output files have unique names.

    Returns:
        A list of zips containing the native libraries.
    """

    if not native_libs and not aar_native_libs:
        return []

    native_zips = []
    cpus = native_libs.keys() if native_libs else aar_native_libs.keys()
    for cpu in cpus:
        native_libs_for_cpu = native_libs[cpu] if cpu in native_libs else depset()
        aar_native_libs_for_cpu = aar_native_libs[cpu] if cpu in aar_native_libs else depset()
        native_zip = make_native_libs_zip(ctx, native_libs_for_cpu, aar_native_libs_for_cpu, sibling, arch = cpu)
        native_zips.append(native_zip)

    return native_zips

def make_native_libs_zip(ctx, native_libs, aar_native_libs, sibling, arch = None):
    """Creates a zip file containing all of the application native libraries for a single CPU architecture.

    Args:
        ctx: The aspect context.
        native_libs: A depset of native libraries.
        aar_native_libs: A depset of native libraries from aar_import targets.
        sibling: Used to ensure output files have unique names.
        arch: The CPU architecture of the native libraries.

    Returns:
        A single zip file containing the native libraries.
    """
    zip_name = "native_libs/native_libs_%s.zip" % arch
    native_zip = utils.isolated_declare_file(ctx, zip_name, sibling = sibling)

    inputs = []
    if native_libs:
        inputs.append(native_libs)
    if aar_native_libs:
        inputs.append(aar_native_libs)

    args = ctx.actions.args()
    args.use_param_file(param_file_arg = "-flagfile=%s", use_always = True)
    args.set_param_file_format("multiline")
    args.add_joined("-lib", native_libs, join_with = ",")
    args.add_joined("-native_libs_zip", aar_native_libs, join_with = ",")
    args.add("-out", native_zip)
    args.add("-architecture", arch)
    ctx.actions.run(
        executable = ctx.executable._android_kit,
        arguments = ["nativelib", args],
        inputs = depset(transitive = inputs),
        outputs = [native_zip],
        mnemonic = "ZipNativeLibs",
        progress_message = "MI Zipping native libs",
    )
    return native_zip

def make_swigdeps_file(ctx, sibling):
    swigdeps_file = utils.isolated_declare_file(
        ctx,
        "native_libs/com.google.wrappers.LoadSwigDeps.txt",
        sibling = sibling,
    )
    ctx.actions.write(swigdeps_file, "lib%s.so" % ctx.label.name)
    return swigdeps_file
