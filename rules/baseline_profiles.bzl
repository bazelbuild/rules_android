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

"""
Defines baseline profiles processing.
"""

load("//rules:utils.bzl", "get_android_toolchain")

def _process(ctx, final_classes_dex, transitive_profiles):
    """ Merges/compiles all the baseline profiles propagated from android_library and aar_import.

    Profiles are compiled with profgen into binary ART profiles. The binary
    profiles will be bundled into the final APK and used at installation time to speed up app
    startup and reduce jank.

    Args:
      ctx: The context.
      final_classes_dex: Final classes zip artifact.
      transitive_profiles: Depset of incoming baseline profile files.

    Returns:
      Provider info containing BaselineProfileProvider for all merged profiles.
    """

    # TODO(b/256652067) Pass proguard_output_map after AppReduce starlark migration.
    proguard_output_map = None
    merge_args = ctx.actions.args()
    profile_dir = ctx.label.name + "-baseline-profile/"
    merged_profile = ctx.actions.declare_file(profile_dir + "static-prof.txt")
    merge_args.add_all(transitive_profiles, before_each = "--input")
    merge_args.add("--output", merged_profile.path)
    ctx.actions.run(
        mnemonic = "MergeBaselineProfiles",
        executable = get_android_toolchain(ctx).merge_baseline_profiles_tool.files_to_run,
        arguments = [merge_args],
        inputs = transitive_profiles,
        outputs = [merged_profile],
        use_default_shell_env = True,
    )

    # Profgen
    output_profile = ctx.actions.declare_file(profile_dir + "baseline.prof")
    output_profile_meta = ctx.actions.declare_file(profile_dir + "baseline.profm")
    profgen_inputs = [final_classes_dex, merged_profile]
    profgen_args = ctx.actions.args()
    profgen_args.add("bin", merged_profile)
    profgen_args.add("--apk", final_classes_dex.path)
    profgen_args.add("--output", output_profile.path)
    profgen_args.add("--output-meta", output_profile_meta.path)
    if proguard_output_map:
        profgen_args.add("--map", proguard_output_map.path)
        profgen_inputs.append(proguard_output_map)
    ctx.actions.run(
        mnemonic = "GenerateARTProfile",
        executable = get_android_toolchain(ctx).profgen.files_to_run,
        progress_message = "Generating Android P-R ART profile for %{label} APK",
        arguments = [profgen_args],
        inputs = profgen_inputs,
        outputs = [output_profile, output_profile_meta],
        use_default_shell_env = True,
    )

    # Zip ART profiles
    output_profile_zip = ctx.actions.declare_file(profile_dir + "art_profile.zip")
    zip_args = ctx.actions.args()
    zip_args.add("c", output_profile_zip)
    zip_args.add(output_profile.path, format = "assets/dexopt/baseline.prof=%s")
    zip_args.add(output_profile_meta.path, format = "assets/dexopt/baseline.profm=%s")
    ctx.actions.run(
        mnemonic = "ZipARTProfiles",
        executable = get_android_toolchain(ctx).zipper.files_to_run,
        progress_message = "Zip ART Profiles for %{label}",
        arguments = [zip_args],
        inputs = [output_profile, output_profile_meta],
        outputs = [output_profile_zip],
        use_default_shell_env = True,
    )
    return BaselineProfileProvider(
        transitive_profiles,
        output_profile_zip,
    )

baseline_profiles = struct(
    process = _process,
)
