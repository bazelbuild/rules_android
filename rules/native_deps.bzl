# Copyright 2022 The Bazel Authors. All rights reserved.
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
Defines the native libs processing and an aspect to collect build configuration
of split deps
"""

load("//rules:providers.bzl", "AndroidBinaryNativeLibsInfo", "AndroidCcLinkParamsInfo", "AndroidNativeLibsInfo")
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("@rules_java//java/common:java_info.bzl", "JavaInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")

visibility(PROJECT_VISIBILITY)

SplitConfigInfo = provider(
    doc = "Provides information about configuration for a split config dep",
    fields = dict(
        build_config = "The build configuration of the dep.",
        target_platform = "The target platform label of the dep.",
    ),
)

def _split_config_aspect_impl(__, ctx):
    android_cfg = ctx.fragments.android
    return SplitConfigInfo(
        build_config = ctx.configuration,
        target_platform = ctx.fragments.platform.platform,
    )

split_config_aspect = aspect(
    implementation = _split_config_aspect_impl,
    fragments = ["android"],
)

def _get_libs_dir_name(target_platform):
    name = target_platform.name
    return name

def process(ctx, filename, merged_libraries_map = {}):
    """Links native deps into a shared library

    Args:
      ctx: The context.
      filename: String. The name of the artifact containing the name of the
            linked shared library

      merged_libraries_map: A dict that maps cpu to a struct describing the librarires produced by
            merging.  The struct is expected to have two fields:
            - new_libraries: New libraries produced by the merging process (e.g. the .so containing
              contents of the merged libraries).
            - stub_libraries: Stub librarires produced by the merging process that should
              replace those with the same names from native depenedencies.

    Returns:
        Tuple of (libs, libs_name) where libs is a depset of all native deps
        and libs_name is a File containing the basename of the linked shared
        library

    """
    target_name = ctx.label.name
    native_libs_basename = None
    libs_name = None
    libs = dict()
    for key, deps in ctx.split_attr.deps.items():
        cc_toolchain_dep = ctx.split_attr._cc_toolchain_split[key]
        cc_toolchain = cc_toolchain_dep[cc_common.CcToolchainInfo]
        build_config = cc_toolchain_dep[SplitConfigInfo].build_config
        libs_dir_name = _get_libs_dir_name(
            cc_toolchain_dep[SplitConfigInfo].target_platform,
        )
        linker_input = cc_common.create_linker_input(
            owner = ctx.label,
            user_link_flags = ["-Wl,-soname=lib" + target_name],
        )
        cc_info = cc_common.merge_cc_infos(
            cc_infos = _concat(
                [CcInfo(linking_context = cc_common.create_linking_context(
                    linker_inputs = depset([linker_input]),
                ))],
                [dep[JavaInfo].cc_link_params_info for dep in deps if JavaInfo in dep],
                [dep[AndroidCcLinkParamsInfo].link_params for dep in deps if AndroidCcLinkParamsInfo in dep],
                [dep[CcInfo] for dep in deps if CcInfo in dep],
            ),
        )
        new_libraries = []
        stub_libraries = []
        if merged_libraries_map:
            new_libraries.extend(merged_libraries_map[key].new_libraries)
            stub_libraries.extend(merged_libraries_map[key].stub_libraries)

        native_deps_lib = _link_native_deps_if_present(ctx, cc_info, cc_toolchain, build_config, target_name)
        if native_deps_lib:
            new_libraries.append(native_deps_lib)
            native_libs_basename = native_deps_lib.basename

        shared_libs = _collect_unique_shared_libs(
            new_libraries,
            stub_libraries,
            cc_info,
        )

        if shared_libs:
            libs[libs_dir_name] = depset(shared_libs)

    if libs and native_libs_basename:
        libs_name = ctx.actions.declare_file("nativedeps_filename/" + target_name + "/" + filename)
        ctx.actions.write(output = libs_name, content = native_libs_basename)

    transitive_native_libs = _get_transitive_native_libs(ctx)
    return AndroidBinaryNativeLibsInfo(
        native_libs = libs,
        native_libs_name = libs_name,
        transitive_native_libs = transitive_native_libs,
    )

# Collect all native shared libraries across split transitions. Some AARs
# contain shared libraries across multiple architectures, e.g. x86 and
# armeabi-v7a, and need to be packed into the APK.
def _get_transitive_native_libs(ctx):
    return depset(
        transitive = [
            dep[AndroidNativeLibsInfo].native_libs
            for deps in ctx.split_attr.deps.values()
            for dep in deps
            if AndroidNativeLibsInfo in dep
        ],
    )

def _all_inputs(cc_info):
    return [
        lib
        for input in cc_info.linking_context.linker_inputs.to_list()
        for lib in input.libraries
    ]

def _collect_unique_shared_libs(new_libraries, stub_libraries, cc_info):
    """Return all the unique shared libraries to be used by the apk.

    New libraries are from external sources, and strictly added to list of shared libraries.
    Stub libraries replace those with the same names from CcInfo (as part of machinery for native
    library merging).

    Also check that there are no duplicates among the new libraries and CcInfo libraries.

    Args:
       new_libraries: Additional libraries that should be used, in addition to those found in
             CcInfo.
       stub_libraries: Libraries that should be used in place of those with the same names
             from CcInfo.
       cc_info: List of CcInfos containing the shared libraries from the build graph.

    Returns:
       The list of shared libraries from all sources.

    """

    # used to exclude so's from cc_info with the same names.
    stub_basenames = {
        library.basename: library
        for library in stub_libraries
    }

    # Used to check duplicate names among new_libraries and cc_info.
    basenames = {
        library.basename: library
        for library in new_libraries
    }

    # Used to check duplicate paths, and whose keys are part of the set of libraries to return.
    artifacts = {
        library: None
        for library in new_libraries
    }
    for input in _all_inputs(cc_info):
        if input.pic_static_library or input.static_library:
            # This is not a shared library and will not be loaded by Android, so skip it.
            continue

        artifact = None
        if input.interface_library:
            if input.resolved_symlink_interface_library:
                artifact = input.resolved_symlink_interface_library
            else:
                artifact = input.interface_library
        elif input.resolved_symlink_dynamic_library:
            artifact = input.resolved_symlink_dynamic_library
        else:
            artifact = input.dynamic_library

        if not artifact:
            fail("Should never happen: did not find artifact for link!")

        basename = artifact.basename
        if artifact in artifacts:
            # We have already reached this library, e.g., through a different solib symlink.
            continue
        if basename in stub_basenames:
            continue
        artifacts[artifact] = None
        if basename in basenames:
            old_artifact = basenames[basename]
            fail(
                "Each library in the transitive closure must have a " +
                "unique basename to avoid name collisions when packaged into " +
                "an apk, but two libraries have the basename '" + basename +
                "': " + str(artifact) + " and " + str(old_artifact) + (
                    " (the library built by this target)" if old_artifact in new_libraries else ""
                ),
            )
        else:
            basenames[basename] = artifact

    return artifacts.keys() + stub_libraries

def _contains_code_to_link(input):
    if not input.static_library and not input.pic_static_library:
        # this is a shared library so we're going to have to copy it
        return False
    if input.objects:
        object_files = input.objects
    elif input.pic_objects:
        object_files = input.pic_objects
    elif _is_any_source_file(input.static_library, input.pic_static_library):
        # this is an opaque library so we're going to have to link it
        return True
    else:
        # if we reach here, this is a cc_library without sources generating an
        # empty archive which does not need to be linked
        # TODO(hvd): replace all such cc_library with exporting_cc_library
        return False
    for obj in object_files:
        if not _is_shared_library(obj):
            # this library was built with a non-shared-library object so we should link it
            return True
    return False

def _is_any_source_file(*files):
    for file in files:
        if file and file.is_source:
            return True
    return False

def _is_shared_library(lib_artifact):
    if (lib_artifact.extension in ["so", "dll", "dylib"]):
        return True

    lib_name = lib_artifact.basename

    # validate against the regex "^.+\\.((so)|(dylib))(\\.\\d\\w*)+$",
    # must match VERSIONED_SHARED_LIBRARY.
    for ext in (".so.", ".dylib."):
        name, _, version = lib_name.rpartition(ext)
        if name and version:
            version_parts = version.split(".")
            for part in version_parts:
                if not part[0].isdigit():
                    return False
                for c in part[1:].elems():
                    if not (c.isalnum() or c == "_"):
                        return False
            return True
    return False

def _is_stamping_enabled(ctx):
    if ctx.configuration.is_tool_configuration():
        return 0
    return getattr(ctx.attr, "stamp", 0)

def _get_build_info(ctx, cc_toolchain):
    # TODO(gnish): This is a temporary workaround until Blaze with Starlark CcToolchainInfo is released.
    if hasattr(cc_toolchain, "_build_info_files"):
        # For Starlark CcToolchainInfo.
        build_info_collection = cc_toolchain._build_info_files
    else:
        # For native CcToolchainInfo.
        build_info_collection = cc_toolchain.build_info_files()
    if _is_stamping_enabled(ctx):
        # Makes the target depend on BUILD_INFO_KEY, which helps to discover stamped targets
        # See b/326620485 for more details.
        ctx.version_file  # buildifier: disable=no-effect
        return build_info_collection.non_redacted_build_info_files.to_list()
    else:
        return build_info_collection.redacted_build_info_files.to_list()

def _get_shared_native_deps_path(
        linker_inputs,
        link_opts,
        linkstamps,
        build_info_artifacts,
        features,
        is_test_target_partially_disabled_thin_lto):
    fp = []
    for artifact in linker_inputs:
        fp.append(artifact.short_path)
    fp.append(str(len(link_opts)))
    for opt in link_opts:
        fp.append(opt)
    for artifact in linkstamps:
        fp.append(artifact.short_path)
    for artifact in build_info_artifacts:
        fp.append(artifact.short_path)
    for feature in features:
        fp.append(feature)

    fp.append("1" if is_test_target_partially_disabled_thin_lto else "0")

    fingerprint = "%x" % hash("".join(fp))
    return "_nativedeps/" + fingerprint

def _get_static_mode_params_for_dynamic_library_libraries(libs):
    linker_inputs = []
    for lib in libs:
        if lib.pic_static_library:
            linker_inputs.append(lib.pic_static_library)
        elif lib.static_library:
            linker_inputs.append(lib.static_library)
        elif lib.interface_library:
            linker_inputs.append(lib.interface_library)
        else:
            linker_inputs.append(lib.dynamic_library)
    return linker_inputs

def _link_native_deps_if_present(ctx, cc_info, cc_toolchain, build_config, target_name, is_test_rule_class = False):
    needs_linking = False
    all_inputs = _all_inputs(cc_info)
    for input in all_inputs:
        needs_linking = needs_linking or _contains_code_to_link(input)

    if not needs_linking or cc_common.is_enabled(
        feature_name = "disable_fallback_native_deps_linking",
        feature_configuration = cc_common.configure_features(
            ctx = ctx,
            cc_toolchain = cc_toolchain,
            unsupported_features = ctx.disabled_features,
        ),
    ):
        return None

    # This does not need to be shareable, but we use this API to specify the
    # custom file root (matching the configuration)
    output_lib = ctx.actions.declare_shareable_artifact(
        paths.join(ctx.label.package, "nativedeps", target_name, "lib" + target_name + ".so"),
        build_config.bin_dir,
    )

    linker_inputs = cc_info.linking_context.linker_inputs.to_list()

    link_opts = []
    for linker_input in linker_inputs:
        for flag in linker_input.user_link_flags:
            link_opts.append(flag)

    linkstamps = []
    for linker_input in linker_inputs:
        linkstamps.extend(linker_input.linkstamps)
    linkstamps_dict = {linkstamp: None for linkstamp in linkstamps}

    build_info_artifacts = _get_build_info(ctx, cc_toolchain) if linkstamps_dict else []
    requested_features = ["static_linking_mode", "native_deps_link"]
    requested_features.extend(ctx.features)
    if not "legacy_whole_archive" in ctx.disabled_features:
        requested_features.append("legacy_whole_archive")
    requested_features = sorted(requested_features)
    feature_config = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = requested_features,
        unsupported_features = ctx.disabled_features,
    )
    partially_disabled_thin_lto = (
        cc_common.is_enabled(
            feature_name = "thin_lto_linkstatic_tests_use_shared_nonlto_backends",
            feature_configuration = feature_config,
        ) and not cc_common.is_enabled(
            feature_name = "thin_lto_all_linkstatic_use_shared_nonlto_backends",
            feature_configuration = feature_config,
        )
    )
    test_only_target = ctx.attr.testonly or is_test_rule_class
    share_native_deps = ctx.fragments.cpp.share_native_deps()

    linker_inputs = _get_static_mode_params_for_dynamic_library_libraries(all_inputs)

    if share_native_deps:
        shared_path = _get_shared_native_deps_path(
            linker_inputs,
            link_opts,
            [linkstamp.file() for linkstamp in linkstamps_dict],
            build_info_artifacts,
            requested_features,
            test_only_target and partially_disabled_thin_lto,
        )
        linked_lib = ctx.actions.declare_shareable_artifact(shared_path + ".so", build_config.bin_dir)
    else:
        linked_lib = output_lib

    cc_common.link(
        name = ctx.label.name,
        actions = ctx.actions,
        linking_contexts = [cc_info.linking_context],
        output_type = "dynamic_library",
        never_link = True,
        native_deps = True,
        feature_configuration = feature_config,
        cc_toolchain = cc_toolchain,
        test_only_target = test_only_target,
        stamp = getattr(ctx.attr, "stamp", 0),
        main_output = linked_lib,
        use_shareable_artifact_factory = True,
        build_config = build_config,
    )

    if (share_native_deps):
        ctx.actions.symlink(
            output = output_lib,
            target_file = linked_lib,
        )
        return output_lib
    else:
        return linked_lib

def _concat(*list_of_lists):
    res = []
    for list in list_of_lists:
        res.extend(list)
    return res
