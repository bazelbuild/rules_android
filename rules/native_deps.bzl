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

load("//rules:common.bzl", "common")

SplitConfigInfo = provider(
    doc = "Provides information about configuration for a split config dep",
    fields = dict(
        build_config = "The build configuration of the dep.",
        android_config = "Select fields from the android configuration of the dep.",
        target_platform = "The target platform label of the dep.",
    ),
)

def _split_config_aspect_impl(__, ctx):
    android_cfg = ctx.fragments.android
    return SplitConfigInfo(
        build_config = ctx.configuration,
        android_config = struct(
            incompatible_use_toolchain_resolution = android_cfg.incompatible_use_toolchain_resolution,
            android_cpu = android_cfg.android_cpu,
            hwasan = android_cfg.hwasan,
        ),
        target_platform = ctx.fragments.platform.platform,
    )

split_config_aspect = aspect(
    implementation = _split_config_aspect_impl,
    fragments = ["android"],
)

def _get_libs_dir_name(android_config, target_platform):
    if android_config.incompatible_use_toolchain_resolution:
        name = target_platform.name
    else:
        # Legacy builds use the CPU as the name.
        name = android_config.android_cpu
    if android_config.hwasan:
        name = name + "-hwasan"
    return name

def process(ctx, filename):
    """ Links native deps into a shared library

    Args:
      ctx: The context.
      filename: String. The name of the artifact containing the name of the
            linked shared library

    Returns:
        Tuple of (libs, libs_name) where libs is a depset of all native deps
        and libs_name is a File containing the basename of the linked shared
        library
    """
    actual_target_name = ctx.label.name.removesuffix(common.PACKAGED_RESOURCES_SUFFIX)
    native_libs_basename = None
    libs_name = None
    libs = dict()
    for key, deps in ctx.split_attr.deps.items():
        cc_toolchain_dep = ctx.split_attr._cc_toolchain_split[key]
        cc_toolchain = cc_toolchain_dep[cc_common.CcToolchainInfo]
        build_config = cc_toolchain_dep[SplitConfigInfo].build_config
        libs_dir_name = _get_libs_dir_name(
            cc_toolchain_dep[SplitConfigInfo].android_config,
            cc_toolchain_dep[SplitConfigInfo].target_platform,
        )
        linker_input = cc_common.create_linker_input(
            owner = ctx.label,
            user_link_flags = ["-Wl,-soname=lib" + actual_target_name],
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
        libraries = []

        native_deps_lib = _link_native_deps_if_present(ctx, cc_info, cc_toolchain, build_config, actual_target_name)
        if native_deps_lib:
            libraries.append(native_deps_lib)
            native_libs_basename = native_deps_lib.basename

        libraries.extend(_filter_unique_shared_libs(native_deps_lib, cc_info))

        if libraries:
            libs[libs_dir_name] = depset(libraries)

    if libs and native_libs_basename:
        libs_name = ctx.actions.declare_file("nativedeps_filename/" + actual_target_name + "/" + filename)
        ctx.actions.write(output = libs_name, content = native_libs_basename)

    transitive_native_libs = _get_transitive_native_libs(ctx)
    return AndroidBinaryNativeLibsInfo(libs, libs_name, transitive_native_libs)

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

def _filter_unique_shared_libs(linked_lib, cc_info):
    basenames = {}
    artifacts = {}
    if linked_lib:
        basenames[linked_lib.basename] = linked_lib
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

        if artifact in artifacts:
            # We have already reached this library, e.g., through a different solib symlink.
            continue
        artifacts[artifact] = None
        basename = artifact.basename
        if basename in basenames:
            old_artifact = basenames[basename]
            fail(
                "Each library in the transitive closure must have a " +
                "unique basename to avoid name collisions when packaged into " +
                "an apk, but two libraries have the basename '" + basename +
                "': " + artifact + " and " + old_artifact + (
                    " (the library compiled for this target)" if old_artifact == linked_lib else ""
                ),
            )
        else:
            basenames[basename] = artifact

    return artifacts.keys()

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

def _get_build_info(ctx):
    return cc_common.get_build_info(ctx)

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

def _link_native_deps_if_present(ctx, cc_info, cc_toolchain, build_config, actual_target_name, is_test_rule_class = False):
    needs_linking = False
    all_inputs = _all_inputs(cc_info)
    for input in all_inputs:
        needs_linking = needs_linking or _contains_code_to_link(input)

    if not needs_linking:
        return None

    # This does not need to be shareable, but we use this API to specify the
    # custom file root (matching the configuration)
    output_lib = ctx.actions.declare_shareable_artifact(
        ctx.label.package + "/nativedeps/" + actual_target_name + "/lib" + actual_target_name + ".so",
        build_config.bin_dir,
    )

    link_opts = cc_info.linking_context.user_link_flags

    linkstamps = []
    for input in cc_info.linking_context.linker_inputs.to_list():
        linkstamps.extend(input.linkstamps)
    linkstamps_dict = {linkstamp: None for linkstamp in linkstamps}

    build_info_artifacts = _get_build_info(ctx) if linkstamps_dict else []
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
