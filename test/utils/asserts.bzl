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

"""Bazel testing library asserts."""

load(
    "//rules:providers.bzl",
    "ResourcesNodeInfo",
    "StarlarkAndroidResourcesInfo",
)

_ATTRS = dict(
    expected_default_info = attr.string_list_dict(),
    expected_java_info = attr.string_list_dict(),
    expected_proguard_spec_provider = attr.string_list_dict(),
    expected_starlark_android_resources_info = attr.label(),
    expected_output_group_info = attr.string_list_dict(),
    expected_native_libs_info = attr.label(),
)

def _expected_resources_node_info_impl(ctx):
    return [
        ResourcesNodeInfo(
            label = ctx.attr.label.label,
            assets = ctx.files.assets,
            assets_dir = ctx.attr.assets_dir,
            assets_symbols = ctx.attr.assets_symbols if ctx.attr.assets_symbols else None,
            compiled_assets = ctx.attr.compiled_assets if ctx.attr.compiled_assets else None,
            compiled_resources = ctx.attr.compiled_resources if ctx.attr.compiled_resources else None,
            r_txt = ctx.attr.r_txt if ctx.attr.r_txt else None,
            manifest = ctx.attr.manifest if ctx.attr.manifest else None,
            exports_manifest = ctx.attr.exports_manifest,
        ),
    ]

_expected_resources_node_info = rule(
    implementation = _expected_resources_node_info_impl,
    attrs = dict(
        label = attr.label(),
        assets = attr.label_list(allow_files = True),
        assets_dir = attr.string(),
        assets_symbols = attr.string(),
        compiled_assets = attr.string(),
        compiled_resources = attr.string(),
        r_txt = attr.string(),
        manifest = attr.string(),
        exports_manifest = attr.bool(default = False),
    ),
)

def ExpectedResourcesNodeInfo(
        label,
        assets = [],
        assets_dir = "",
        assets_symbols = None,
        compiled_assets = None,
        compiled_resources = None,
        r_txt = None,
        manifest = None,
        exports_manifest = False,
        name = "unused"):  # appease linter
    name = label + str(assets) + assets_dir + str(assets_symbols) + str(compiled_resources) + str(exports_manifest)
    name = ":" + "".join([c for c in name.elems() if c != ":"])

    _expected_resources_node_info(
        name = name[1:],
        label = label,
        assets = assets,
        assets_dir = assets_dir,
        assets_symbols = assets_symbols,
        compiled_assets = compiled_assets,
        compiled_resources = compiled_resources,
        r_txt = r_txt,
        manifest = manifest,
        exports_manifest = exports_manifest,
    )
    return name

def _expected_starlark_android_resources_info_impl(ctx):
    return [
        StarlarkAndroidResourcesInfo(
            direct_resources_nodes = [node[ResourcesNodeInfo] for node in ctx.attr.direct_resources_nodes],
            transitive_resources_nodes = [node[ResourcesNodeInfo] for node in ctx.attr.transitive_resources_nodes],
            transitive_assets = ctx.attr.transitive_assets,
            transitive_assets_symbols = ctx.attr.transitive_assets_symbols,
            transitive_compiled_resources = ctx.attr.transitive_compiled_resources,
            packages_to_r_txts = ctx.attr.packages_to_r_txts,
        ),
    ]

_expected_starlark_android_resources_info = rule(
    implementation = _expected_starlark_android_resources_info_impl,
    attrs = dict(
        direct_resources_nodes = attr.label_list(
            providers = [ResourcesNodeInfo],
        ),
        transitive_resources_nodes = attr.label_list(
            providers = [ResourcesNodeInfo],
        ),
        transitive_assets = attr.string_list(),
        transitive_assets_symbols = attr.string_list(),
        transitive_compiled_resources = attr.string_list(),
        packages_to_r_txts = attr.string_list_dict(),
    ),
)

def ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = None,
        transitive_resources_nodes = [],
        transitive_assets = [],
        transitive_assets_symbols = [],
        transitive_compiled_resources = [],
        packages_to_r_txts = {},
        name = "unused"):  # appease linter
    name = (str(direct_resources_nodes) + str(transitive_resources_nodes) + str(transitive_assets) +
            str(transitive_assets_symbols) + str(transitive_compiled_resources))
    name = ":" + "".join([c for c in name.elems() if c not in [":", "\\"]])
    _expected_starlark_android_resources_info(
        name = name[1:],
        direct_resources_nodes = direct_resources_nodes,
        transitive_resources_nodes = transitive_resources_nodes,
        transitive_assets = transitive_assets,
        transitive_assets_symbols = transitive_assets_symbols,
        transitive_compiled_resources = transitive_compiled_resources,
        packages_to_r_txts = packages_to_r_txts,
    )
    return name

def _build_expected_resources_node_info(string):
    parts = string.split(":")
    if len(parts) != 5:
        fail("Error: malformed resources_node_info string: %s" % string)
    return dict(
        label = parts[0],
        assets = parts[1].split(",") if parts[1] else [],
        assets_dir = parts[2],
        assets_symbols = parts[3],
        compiled_resources = parts[4],
    )

def _expected_android_binary_native_libs_info_impl(ctx):
    return _ExpectedAndroidBinaryNativeInfo(
        transitive_native_libs = ctx.attr.transitive_native_libs,
        native_libs_name = ctx.attr.native_libs_name,
        native_libs = ctx.attr.native_libs,
    )

_expected_android_binary_native_libs_info = rule(
    implementation = _expected_android_binary_native_libs_info_impl,
    attrs = {
        "transitive_native_libs": attr.string_list(),
        "native_libs_name": attr.string(),
        "native_libs": attr.string_list_dict(),
    },
)

def ExpectedAndroidBinaryNativeLibsInfo(**kwargs):
    name = "".join([str(kwargs[param]) for param in kwargs])
    name = ":" + "".join([c for c in name.elems() if c not in [" ", "[", "]", ":", "\\", "{", "\""]])
    _expected_android_binary_native_libs_info(name = name[1:], **kwargs)
    return name

_ExpectedAndroidBinaryNativeInfo = provider(
    "Test provider to compare native deps info",
    fields = ["native_libs", "native_libs_name", "transitive_native_libs"],
)

def _assert_native_libs_info(expected, actual):
    expected = expected[_ExpectedAndroidBinaryNativeInfo]
    if expected.native_libs_name:
        _assert_file(
            expected.native_libs_name,
            actual.native_libs_name,
            "AndroidBinaryNativeInfo.native_libs_name",
        )
    for config in expected.native_libs:
        if config not in actual.native_libs:
            fail("Error for AndroidBinaryNativeInfo.native_libs: expected key %s was not found" % config)
        _assert_files(
            expected.native_libs[config],
            actual.native_libs[config].to_list(),
            "AndroidBinaryNativeInfo.native_libs." + config,
        )
    _assert_files(
        expected.transitive_native_libs,
        actual.transitive_native_libs.to_list(),
        "AndroidBinaryNativeInfo.transitive_native_libs",
    )

def _assert_files(expected_file_names, actual_files, error_msg_field_name):
    """Asserts that expected file names and actual list of files is equal.

    Args:
      expected_file_names: The expected names of file basenames (no path),
      actual_files: The actual list of files produced.
      error_msg_field_name: The field the actual list of files is from.
    """
    actual_file_names = [f.basename for f in actual_files]
    if sorted(actual_file_names) == sorted(expected_file_names):
        return
    fail("""Error for %s, expected and actual file names are not the same:
expected file names: %s
actual files: %s
""" % (error_msg_field_name, expected_file_names, actual_files))

def _assert_file_objects(expected_files, actual_files, error_msg_field_name):
    if sorted([f.basename for f in expected_files]) == sorted([f.basename for f in actual_files]):
        return
    fail("""Error for %s, expected and actual file names are not the same:
expected file names: %s
actual files: %s
""" % (error_msg_field_name, expected_files, actual_files))

def _assert_file_depset(expected_file_paths, actual_depset, error_msg_field_name, ignore_label_prefix = ""):
    """Asserts that expected file short_paths and actual depset of files is equal.

    Args:
      expected_file_paths: The expected file short_paths in depset order.
      actual_depset: The actual depset produced.
      error_msg_field_name: The field the actual depset is from.
      ignore_label_prefix: Path prefix to ignore on actual file short_paths.
    """
    actual_paths = []  # = [f.short_path for f in actual_depset.to_list()]
    for f in actual_depset.to_list():
        path = f.short_path
        if path.startswith(ignore_label_prefix):
            path = path[len(ignore_label_prefix):]
        actual_paths.append(path)

    if len(expected_file_paths) != len(actual_paths):
        fail("""Error for %s, expected %d items, got %d items
expected: %s
actual: %s""" % (
            error_msg_field_name,
            len(expected_file_paths),
            len(actual_paths),
            expected_file_paths,
            actual_paths,
        ))
    for i in range(len(expected_file_paths)):
        if expected_file_paths[i] != actual_paths[i]:
            fail("""Error for %s, actual file depset ordering does not match expected ordering:
expected ordering: %s
actual ordering: %s
""" % (error_msg_field_name, expected_file_paths, actual_paths))

def _assert_empty(contents, error_msg_field_name):
    """Asserts that the given is empty."""
    if len(contents) == 0:
        return
    fail("Error %s is not empty: %s" % (error_msg_field_name, contents))

def _assert_none(content, error_msg_field_name):
    """Asserts that the given is None."""
    if content == None:
        return
    fail("Error %s is not None: %s" % (error_msg_field_name, content))

def _assert_java_info(expected, actual):
    """Asserts that expected matches actual JavaInfo.

    Args:
      expected: A dict containing fields of a JavaInfo that are compared against
        the actual given JavaInfo.
      actual: A JavaInfo.
    """
    for key in expected.keys():
        if not hasattr(actual, key):
            fail("Actual JavaInfo does not have attribute %s:\n%s" % (key, actual))
        actual_attr = getattr(actual, key)
        expected_attr = expected[key]

        # files based asserts.
        if key in [
            "compile_jars",
            "runtime_output_jars",
            "source_jars",
            "transitive_compile_time_jars",
            "transitive_runtime_jars",
            "transitive_source_jars",
        ]:
            files = \
                actual_attr if type(actual_attr) == "list" else actual_attr.to_list()
            _assert_files(expected_attr, files, "JavaInfo.%s" % key)
        else:
            fail("Error validation of JavaInfo.%s not implemented." % key)

def _assert_default_info(
        expected,
        actual):
    """Asserts that the DefaultInfo contains the expected values."""
    if not expected:
        return

    # DefaultInfo.data_runfiles Assertions
    _assert_empty(
        actual.data_runfiles.empty_filenames.to_list(),
        "DefaultInfo.data_runfiles.empty_filenames",
    )
    _assert_files(
        expected["runfiles"],
        actual.data_runfiles.files.to_list(),
        "DefaultInfo.data_runfiles.files",
    )
    _assert_empty(
        actual.data_runfiles.symlinks.to_list(),
        "DefaultInfo.data_runfiles.symlinks",
    )

    # DefaultInfo.default_runfile Assertions
    _assert_empty(
        actual.default_runfiles.empty_filenames.to_list(),
        "DefaultInfo.default_runfiles.empty_filenames",
    )
    _assert_files(
        expected["runfiles"],
        actual.default_runfiles.files.to_list(),
        "DefaultInfo.default_runfiles.files",
    )
    _assert_empty(
        actual.default_runfiles.symlinks.to_list(),
        "DefaultInfo.default_runfiles.symlinks",
    )

    # DefaultInfo.files Assertion
    _assert_files(
        expected["files"],
        actual.files.to_list(),
        "DefaultInfo.files",
    )

    # DefaultInfo.files_to_run Assertions
    _assert_none(
        actual.files_to_run.executable,
        "DefaultInfo.files_to_run.executable",
    )
    _assert_none(
        actual.files_to_run.runfiles_manifest,
        "DefaultInfo.files_to_run.runfiles_manifest",
    )

def _assert_proguard_spec_provider(expected, actual):
    """Asserts that expected matches actual ProguardSpecProvider.

    Args:
      expected: A dict containing fields of a ProguardSpecProvider that are
        compared against the actual given ProguardSpecProvider.
      actual: A ProguardSpecProvider.
    """
    for key in expected.keys():
        if not hasattr(actual, key):
            fail("Actual ProguardSpecProvider does not have attribute %s:\n%s" % (key, actual))
        actual_attr = getattr(actual, key)
        expected_attr = expected[key]
        if key in ["specs"]:
            _assert_files(
                expected_attr,
                actual_attr.to_list(),
                "ProguardSpecProvider.%s" % key,
            )
        else:
            fail("Error validation of ProguardSpecProvider.%s not implemented." % key)

def _assert_string(expected, actual, error_msg):
    if type(actual) != "string":
        fail("Error for %s, actual value not of type string, got %s" % (error_msg, type(actual)))
    if actual != expected:
        fail("""Error for %s, expected and actual values are not the same:
expected value: %s
actual value: %s
""" % (error_msg, expected, actual))

def _assert_file(expected, actual, error_msg_field_name):
    if actual == None and expected == None:
        return

    if actual == None and expected != None:
        fail("Error at %s, expected %s but got None" % (error_msg_field_name, expected))

    if type(actual) != "File":
        fail("Error at %s, expected a File but got %s" % (error_msg_field_name, type(actual)))

    if actual != None and expected == None:
        fail("Error at %s, expected None but got %s" % (error_msg_field_name, actual.short_path))

    ignore_label_prefix = actual.owner.package + "/"
    actual_path = actual.short_path
    if actual_path.startswith(ignore_label_prefix):
        actual_path = actual_path[len(ignore_label_prefix):]
    _assert_string(expected, actual_path, error_msg_field_name)

def _assert_resources_node_info(expected, actual):
    if type(actual.label) != "Label":
        fail("Error for ResourcesNodeInfo.label, expected type Label, actual type is %s" % type(actual.label))
    _assert_string(expected.label.name, actual.label.name, "ResourcesNodeInfo.label.name")

    if type(actual.assets) != "depset":
        fail("Error for ResourcesNodeInfo.assets, expected type depset, actual type is %s" % type(actual.assets))

    # TODO(djwhang): Align _assert_file_objects and _assert_file_depset to work
    # in a similar manner. For now, we will just call to_list() as this field
    # was list prior to this change.
    _assert_file_objects(expected.assets, actual.assets.to_list(), "ResourcesNodeInfo.assets")

    _assert_string(expected.assets_dir, actual.assets_dir, "ResourcesNodeInfo.assets_dir")

    _assert_file(
        expected.assets_symbols,
        actual.assets_symbols,
        "ResourcesNodeInfo.assets_symbols",
    )

    _assert_file(
        expected.compiled_assets,
        actual.compiled_assets,
        "ResourcesNodeInfo.compiled_assets",
    )

    _assert_file(
        expected.compiled_resources,
        actual.compiled_resources,
        "ResourcesNodeInfo.compiled_resources",
    )

    _assert_file(
        expected.r_txt,
        actual.r_txt,
        "ResourcesNodeInfo.r_txt",
    )

    _assert_file(
        expected.manifest,
        actual.manifest,
        "ResourcesNodeInfo.manifest",
    )

    if type(actual.exports_manifest) != "bool":
        fail("Error for ResourcesNodeInfo.exports_manifest, expected type bool, actual type is %s" % type(actual.exports_manifest))
    if expected.exports_manifest != actual.exports_manifest:
        fail("""Error for ResourcesNodeInfo.exports_manifest, expected and actual values are not the same:
expected value: %s
actual value: %s
""" % (expected.exports_manifest, actual.exports_manifest))

def _assert_resources_node_info_depset(expected_resources_node_infos, actual_depset, error_msg):
    actual_resources_node_infos = actual_depset.to_list()
    if len(expected_resources_node_infos) != len(actual_resources_node_infos):
        fail(
            "Error for StarlarkAndroidResourcesInfo.%s, expected size of list to be %d, got %d:\nExpected: %s\nActual: %s" %
            (
                error_msg,
                len(expected_resources_node_infos),
                len(actual_resources_node_infos),
                [node.label for node in expected_resources_node_infos],
                [node.label for node in actual_resources_node_infos],
            ),
        )
    for i in range(len(actual_resources_node_infos)):
        _assert_resources_node_info(expected_resources_node_infos[i], actual_resources_node_infos[i])

def _assert_starlark_android_resources_info(expected, actual, label_under_test):
    _assert_resources_node_info_depset(
        expected.direct_resources_nodes,
        actual.direct_resources_nodes,
        "direct_resources_nodes",
    )

    _assert_resources_node_info_depset(
        expected.transitive_resources_nodes,
        actual.transitive_resources_nodes,
        "transitive_resources_nodes",
    )

    # Use the package from the target under test to shrink actual paths being compared down to the
    # name of the target.
    ignore_label_prefix = label_under_test.package + "/"

    _assert_file_depset(
        expected.transitive_assets,
        actual.transitive_assets,
        "StarlarkAndroidResourcesInfo.transitive_assets",
        ignore_label_prefix,
    )
    _assert_file_depset(
        expected.transitive_assets_symbols,
        actual.transitive_assets_symbols,
        "StarlarkAndroidResourcesInfo.transitive_assets_symbols",
        ignore_label_prefix,
    )
    _assert_file_depset(
        expected.transitive_compiled_resources,
        actual.transitive_compiled_resources,
        "StarlarkAndroidResourcesInfo.transitive_compiled_resources",
        ignore_label_prefix,
    )
    for pkg, value in expected.packages_to_r_txts.items():
        if pkg in actual.packages_to_r_txts:
            _assert_file_depset(
                value,
                actual.packages_to_r_txts[pkg],
                "StarlarkAndroidResourcesInfo.packages_to_r_txts[%s]" % pkg,
                ignore_label_prefix,
            )
        else:
            fail("Error for StarlarkAndroidResourceInfo.packages_to_r_txts, expected key %s was not found" % pkg)

_R_CLASS_ATTRS = dict(
    _r_class_check = attr.label(
        default = "//test/utils/java/com/google:RClassChecker_deploy.jar",
        executable = True,
        allow_files = True,
        cfg = "exec",
    ),
    expected_r_class_fields = attr.string_list(),
)

def _assert_output_group_info(expected, actual):
    for key in expected:
        actual_attr = getattr(actual, key, None)
        if actual_attr == None:  # both empty depset and list will fail.
            fail("%s is not defined in OutputGroupInfo: %s" % (key, actual))
        _assert_files(
            expected[key],
            actual_attr.to_list(),
            "OutputGroupInfo." + key,
        )

def _is_suffix_sublist(full, suffixes):
    """Returns whether suffixes is a sublist of suffixes of full."""
    for (fi, _) in enumerate(full):
        sublist_match = True
        for (si, sv) in enumerate(suffixes):
            if (fi + si >= len(full)) or not full[fi + si].endswith(sv):
                sublist_match = False
                break
        if sublist_match:
            return True
    return False

def _check_actions(inspect, actions):
    for mnemonic, expected_argvs in inspect.items():
        # Action mnemonic is not unique, even in the context of a target, hence
        # it is necessary to find all actions and compare argv. If there are no
        # matches among the actions that match the mnemonic, fail and present
        # all the possible actions that could have matched.
        mnemonic_matching_actions = []
        mnemonic_match = False
        for _, value in actions.by_file.items():
            if mnemonic != value.mnemonic:
                continue
            mnemonic_match = True

            if _is_suffix_sublist(value.argv, expected_argvs):
                # When there is a match, clear the actions stored for displaying
                # an error messaage.
                mnemonic_matching_actions = []
                break
            else:
                mnemonic_matching_actions.append(value)

        if not mnemonic_match:
            fail("%s action not found." % mnemonic)
        if mnemonic_matching_actions:
            # If there are mnemonic_matching_actions, then the argvs did not
            # align. Fail but show the other actions that were created.
            error_message = (
                "%s with the following argv not found: %s\nSimilar actions:\n" %
                (mnemonic, expected_argvs)
            )
            for i, action in enumerate(mnemonic_matching_actions):
                error_message += (
                    "%d. Progress Message: %s\n   Argv:             %s\n\n" %
                    (i + 1, action, action.argv)
                )
            fail(error_message)

_ACTIONS_ATTRS = dict(
    inspect_actions = attr.string_list_dict(),
)

asserts = struct(
    provider = struct(
        attrs = _ATTRS,
        default_info = _assert_default_info,
        java_info = _assert_java_info,
        proguard_spec_provider = _assert_proguard_spec_provider,
        starlark_android_resources_info = _assert_starlark_android_resources_info,
        output_group_info = _assert_output_group_info,
        native_libs_info = _assert_native_libs_info,
    ),
    files = _assert_files,
    r_class = struct(
        attrs = _R_CLASS_ATTRS,
    ),
    actions = struct(
        attrs = _ACTIONS_ATTRS,
        check_actions = _check_actions,
    ),
)
