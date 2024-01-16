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

load(":utils.bzl", "utils")

def make_native_zip(ctx, native_libs, aar_native_libs, sibling):
    """Creates a zip file containing all of the application native libraries."""
    input = []
    lib_flag = []
    for cpu, files in native_libs.items():
        input.extend(files.to_list())
        lib_flag.extend([cpu + ":" + f.path for f in files.to_list()])

    native_zip = None
    if input or aar_native_libs:
        native_zip = utils.isolated_declare_file(ctx, "native_libs/native_libs.zip", sibling = sibling)

        args = ctx.actions.args()
        args.use_param_file(param_file_arg = "-flagfile=%s", use_always = True)
        args.set_param_file_format("multiline")
        args.add_joined("-lib", lib_flag, join_with = ",")
        args.add("-out", native_zip)
        if aar_native_libs:
            args.add_joined("-native_libs_zip", aar_native_libs, join_with = ",")
            input = depset(input, transitive = [aar_native_libs])

        ctx.actions.run(
            executable = ctx.executable._android_kit,
            arguments = ["nativelib", args],
            inputs = input,
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
