# Tests for resource processing

load(
    "//test/utils:asserts.bzl",
    "ExpectedResourcesNodeInfo",
    "ExpectedStarlarkAndroidResourcesInfo",
)
load("//test/utils:lib.bzl", "failure_test")
load(
    ":test.bzl",
    "FakeSplitTransitionTarget",
    "filter_multi_cpu_configuration_targets_test",
    "package_resources_final_id_test",
    "resources_package",
    "resources_package_test",
    "starlark_process",
    "starlark_process_test",
)

package(default_applicable_licenses = ["//:license"])

licenses(["notice"])

# Used in android_binary resources diff test
exports_files(
    ["test_stub_script.sh"],
)

starlark_process(
    name = "no_resources_and_manifest",
)

empty_resources_info = ExpectedStarlarkAndroidResourcesInfo()

starlark_process_test(
    name = "test_no_resources_and_manifest",
    expected_starlark_android_resources_info = empty_resources_info,
    target_under_test = ":no_resources_and_manifest",
)

starlark_process(
    name = "resource_processing",
    assets = ["assets/some_asset.txt"],
    assets_dir = "assets",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
)

resource_processing_resources_node = ExpectedResourcesNodeInfo(
    assets = ["assets/some_asset.txt"],
    assets_dir = "assets",
    assets_symbols = "resource_processing_symbols/assets.bin",
    compiled_assets = "resource_processing_symbols/assets.zip",
    compiled_resources = "resource_processing_symbols/symbols.zip",
    label = ":resource_processing",
    manifest = "resource_processing_processed_manifest/AndroidManifest.xml",
    r_txt = "resource_processing_symbols/R.aapt2.txt",
)

resource_processing_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
    direct_resources_nodes = [resource_processing_resources_node],
    transitive_assets = [
        "assets/some_asset.txt",
    ],
    transitive_assets_symbols = ["resource_processing_symbols/assets.bin"],
    transitive_compiled_resources = ["resource_processing_symbols/symbols.zip"],
    transitive_resources_nodes = [],
)

starlark_process_test(
    name = "test_resource_processing",
    expected_r_class_fields = [
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = resource_processing_android_resources_info,
    target_under_test = ":resource_processing",
)

starlark_process(
    name = "resource_processing_without_stamping_manifest",
    assets = ["assets/some_asset.txt"],
    assets_dir = "assets",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res/**"]),
    stamp_manifest = False,
)

starlark_process_test(
    name = "test_resource_processing_without_stamping_manifest",
    expected_r_class_fields = [
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = resource_processing_android_resources_info,
    target_under_test = ":resource_processing",
)

filegroup(
    name = "resource_files_filegroup",
    srcs = glob(["res/**"]),
)

starlark_process(
    name = "resource_processing_res_from_filegroup",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = [":resource_files_filegroup"],
)

starlark_process_test(
    name = "test_resource_processing_res_from_filegroup",
    expected_r_class_fields = [
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets = [],
                assets_dir = "",
                assets_symbols =
                    "resource_processing_res_from_filegroup_symbols/assets.bin",
                compiled_resources =
                    "resource_processing_res_from_filegroup_symbols/symbols.zip",
                label = ":resource_processing_res_from_filegroup",
                manifest =
                    "resource_processing_res_from_filegroup_processed_manifest/AndroidManifest.xml",
                r_txt =
                    "resource_processing_res_from_filegroup_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets = [],
        transitive_assets_symbols = [
            "resource_processing_res_from_filegroup_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "resource_processing_res_from_filegroup_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [],
    ),
    target_under_test = ":resource_processing_res_from_filegroup",
)

filegroup(
    name = "resource_files_from_nested_filegroups",
    srcs = [":resource_files_filegroup"],
)

starlark_process(
    name = "resource_processing_res_from_nested_filegroups",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = [":resource_files_from_nested_filegroups"],
)

starlark_process_test(
    name = "test_resource_processing_res_from_nested_filegroups",
    expected_r_class_fields = [
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets = [],
                assets_dir = "",
                assets_symbols =
                    "resource_processing_res_from_nested_filegroups_symbols/assets.bin",
                compiled_resources =
                    "resource_processing_res_from_nested_filegroups_symbols/symbols.zip",
                label = ":resource_processing_res_from_nested_filegroups",
                manifest =
                    "resource_processing_res_from_nested_filegroups_processed_manifest/AndroidManifest.xml",
                r_txt =
                    "resource_processing_res_from_nested_filegroups_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets = [],
        transitive_assets_symbols = [
            "resource_processing_res_from_nested_filegroups_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "resource_processing_res_from_nested_filegroups_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [],
    ),
    target_under_test = ":resource_processing_res_from_nested_filegroups",
)

starlark_process(
    name = "no_resources_and_manifest_with_dep_without_res",
    deps = [":no_resources_and_manifest"],
)

starlark_process_test(
    name = "test_no_resources_and_manifest_with_dep_without_res",
    expected_starlark_android_resources_info = empty_resources_info,
    target_under_test = ":no_resources_and_manifest_with_dep_without_res",
)

# Library with no resources and a single dep with resources
starlark_process(
    name = "no_resources_with_dep_with_res",
    deps = [":resource_processing"],
)

starlark_process_test(
    name = "test_no_resources_with_dep_with_res",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [],
        transitive_assets = [
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
        ],
    ),
    target_under_test = ":no_resources_with_dep_with_res",
)

# Library with a manifest but no resource_files, with a single dep with resources
starlark_process(
    name = "manifest_without_resource_files_with_dep_with_res",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    deps = [":resource_processing"],
)

starlark_process_test(
    name = "test_manifest_without_resource_files_with_dep_with_res",
    expected_r_class_fields = [
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [ExpectedResourcesNodeInfo(
            assets = [],
            assets_dir = "",
            assets_symbols = "manifest_without_resource_files_with_dep_with_res_symbols/assets.bin",
            compiled_resources = "manifest_without_resource_files_with_dep_with_res_symbols/symbols.zip",
            label = ":manifest_without_resource_files_with_dep_with_res",
            manifest =
                "manifest_without_resource_files_with_dep_with_res_processed_manifest/AndroidManifest.xml",
            r_txt =
                "manifest_without_resource_files_with_dep_with_res_symbols/R.aapt2.txt",
        )],
        transitive_assets = [
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "manifest_without_resource_files_with_dep_with_res_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "manifest_without_resource_files_with_dep_with_res_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
        ],
    ),
    target_under_test = ":manifest_without_resource_files_with_dep_with_res",
)

# Library with resources and a single dep with resources
starlark_process(
    name = "resources_with_dep_with_res",
    assets = ["assets3/some_asset.txt"],
    assets_dir = "assets",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res_b/**"]),
    deps = [":resource_processing"],
)

resources_with_dep_with_res_resources_node = ExpectedResourcesNodeInfo(
    assets = ["assets3/some_asset.txt"],
    assets_dir = "assets",
    assets_symbols = "resources_with_dep_with_res_symbols/assets.bin",
    compiled_assets =
        "resources_with_dep_with_res_symbols/assets.zip",
    compiled_resources =
        "resources_with_dep_with_res_symbols/symbols.zip",
    label = ":resources_with_dep_with_res",
    manifest =
        "resources_with_dep_with_res_processed_manifest/AndroidManifest.xml",
    r_txt = "resources_with_dep_with_res_symbols/R.aapt2.txt",
)

starlark_process_test(
    name = "test_resources_with_dep_with_res",
    expected_r_class_fields = [
        "string.my_other_string",
        "string.my_string",
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [resources_with_dep_with_res_resources_node],
        transitive_assets = [
            "assets3/some_asset.txt",
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "resources_with_dep_with_res_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "resources_with_dep_with_res_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
        ],
    ),
    target_under_test = ":resources_with_dep_with_res",
)

# Library with two deps with resources
starlark_process(
    name = "another_resource_processing_lib",
    assets = ["assets/some_asset.txt"],
    assets_dir = "assets",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res_a/**"]),
)

another_resource_processing_lib_resources_node = ExpectedResourcesNodeInfo(
    assets = ["assets/some_asset.txt"],
    assets_dir = "assets",
    assets_symbols =
        "another_resource_processing_lib_symbols/assets.bin",
    compiled_assets =
        "another_resource_processing_lib_symbols/assets.zip",
    compiled_resources =
        "another_resource_processing_lib_symbols/symbols.zip",
    label = ":another_resource_processing_lib",
    manifest =
        "another_resource_processing_lib_processed_manifest/AndroidManifest.xml",
    r_txt =
        "another_resource_processing_lib_symbols/R.aapt2.txt",
)

starlark_process(
    name = "res_with_two_deps_and_resources",
    assets = ["assets2/data/data.txt"],
    assets_dir = "assets2",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res_b/**"]),
    deps = [
        ":another_resource_processing_lib",
        ":resource_processing",
    ],
)

res_with_two_deps_and_resources_resources_node = ExpectedResourcesNodeInfo(
    assets = ["assets2/data/data.txt"],
    assets_dir = "assets2",
    assets_symbols =
        "res_with_two_deps_and_resources_symbols/assets.bin",
    compiled_assets =
        "res_with_two_deps_and_resources_symbols/assets.zip",
    compiled_resources =
        "res_with_two_deps_and_resources_symbols/symbols.zip",
    label = ":res_with_two_deps_and_resources",
    manifest =
        "res_with_two_deps_and_resources_processed_manifest/AndroidManifest.xml",
    r_txt = "res_with_two_deps_and_resources_symbols/R.aapt2.txt",
)

starlark_process_test(
    name = "test_res_with_two_deps_and_resources",
    expected_r_class_fields = [
        "string.my_string",
        "string.my_other_string",
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [res_with_two_deps_and_resources_resources_node],
        transitive_assets = [
            "assets2/data/data.txt",
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "res_with_two_deps_and_resources_symbols/assets.bin",
            "another_resource_processing_lib_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "res_with_two_deps_and_resources_symbols/symbols.zip",
            "another_resource_processing_lib_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            another_resource_processing_lib_resources_node,
            resource_processing_resources_node,
        ],
    ),
    target_under_test = ":res_with_two_deps_and_resources",
)

# Library with transitive deps with resources, “linked list” structure of A depends on B depends on C
starlark_process(
    name = "has_direct_and_transitive_dependencies",
    assets = ["assets2/data/data.txt"],
    assets_dir = "assets2",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res_b/**"]),
    deps = [":resources_with_dep_with_res"],
)

starlark_process_test(
    name = "test_has_direct_and_transitive_dependencies",
    expected_r_class_fields = [
        "string.my_other_string",
        "string.my_string",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets = ["assets2/data/data.txt"],
                assets_dir = "assets2",
                assets_symbols =
                    "has_direct_and_transitive_dependencies_symbols/assets.bin",
                compiled_assets =
                    "has_direct_and_transitive_dependencies_symbols/assets.zip",
                compiled_resources =
                    "has_direct_and_transitive_dependencies_symbols/symbols.zip",
                label = ":has_direct_and_transitive_dependencies",
                manifest =
                    "has_direct_and_transitive_dependencies_processed_manifest/AndroidManifest.xml",
                r_txt =
                    "has_direct_and_transitive_dependencies_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets = [
            "assets2/data/data.txt",
            "assets3/some_asset.txt",
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "has_direct_and_transitive_dependencies_symbols/assets.bin",
            "resources_with_dep_with_res_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "has_direct_and_transitive_dependencies_symbols/symbols.zip",
            "resources_with_dep_with_res_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
            resources_with_dep_with_res_resources_node,
        ],
    ),
    target_under_test = ":has_direct_and_transitive_dependencies",
)

# Strict deps disabled. Library with transitive deps with resources, “linked list” structure of A depends on B depends on C
starlark_process(
    name = "no_strict_deps_has_direct_and_transitive_dependencies",
    custom_package = "test.rules.resources",
    features = ["-android_resources_strict_deps"],
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res_strict_deps/**"]),
    deps = [":resources_with_dep_with_res"],
)

starlark_process_test(
    name = "test_no_strict_deps_has_direct_and_transitive_dependencies",
    expected_r_class_fields = [
        # Primary resources
        "string.strict_deps",
        # Resources from direct dep (":resources_with_dep_with_res")
        "string.my_other_string",
        "string.my_string",
        # Resources from transitive dep (":resource_processing")
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets = [],
                assets_dir = "",
                assets_symbols =
                    "no_strict_deps_has_direct_and_transitive_dependencies_symbols/assets.bin",
                compiled_resources =
                    "no_strict_deps_has_direct_and_transitive_dependencies_symbols/symbols.zip",
                label = ":no_strict_deps_has_direct_and_transitive_dependencies",
                manifest =
                    "no_strict_deps_has_direct_and_transitive_dependencies_processed_manifest/AndroidManifest.xml",
                r_txt =
                    "no_strict_deps_has_direct_and_transitive_dependencies_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets = [
            "assets3/some_asset.txt",
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "no_strict_deps_has_direct_and_transitive_dependencies_symbols/assets.bin",
            "resources_with_dep_with_res_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "no_strict_deps_has_direct_and_transitive_dependencies_symbols/symbols.zip",
            "resources_with_dep_with_res_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
            resources_with_dep_with_res_resources_node,
        ],
    ),
    target_under_test = ":no_strict_deps_has_direct_and_transitive_dependencies",
)

# Library with transitive deps with resources, “linked list” structure of A depends on B depends on C,
# where B has no deps
starlark_process(
    name = "has_direct_without_res_and_transitive_with_res",
    assets = ["assets2/data/data.txt"],
    assets_dir = "assets2",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["res_c/**"]),
    deps = [":no_resources_with_dep_with_res"],
)

starlark_process_test(
    name = "test_has_direct_without_res_and_transitive_with_res",
    expected_r_class_fields = [
        "string.my_string",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets = ["assets2/data/data.txt"],
                assets_dir = "assets2",
                assets_symbols =
                    "has_direct_without_res_and_transitive_with_res_symbols/assets.bin",
                compiled_assets =
                    "has_direct_without_res_and_transitive_with_res_symbols/assets.zip",
                compiled_resources =
                    "has_direct_without_res_and_transitive_with_res_symbols/symbols.zip",
                label = ":has_direct_without_res_and_transitive_with_res",
                manifest =
                    "has_direct_without_res_and_transitive_with_res_processed_manifest/AndroidManifest.xml",
                r_txt =
                    "has_direct_without_res_and_transitive_with_res_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets = [
            "assets2/data/data.txt",
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "has_direct_without_res_and_transitive_with_res_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "has_direct_without_res_and_transitive_with_res_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
        ],
    ),
    target_under_test = ":has_direct_without_res_and_transitive_with_res",
)

# Library with transitive deps with resources, “Dense tree” structure of A depends on multiple deps,
# which each have additional deps.
starlark_process(
    name = "multiple_deps_with_res_processing",
    deps = [
        "res_with_two_deps_and_resources",
        "resources_with_dep_with_res",
    ],
)

starlark_process_test(
    name = "test_multiple_deps_with_res_processing",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [],
        transitive_assets = [
            "assets2/data/data.txt",
            "assets/some_asset.txt",
            "assets3/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "res_with_two_deps_and_resources_symbols/assets.bin",
            "another_resource_processing_lib_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
            "resources_with_dep_with_res_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "res_with_two_deps_and_resources_symbols/symbols.zip",
            "another_resource_processing_lib_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
            "resources_with_dep_with_res_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            another_resource_processing_lib_resources_node,
            resource_processing_resources_node,
            res_with_two_deps_and_resources_resources_node,
            resources_with_dep_with_res_resources_node,
        ],
    ),
    target_under_test = ":multiple_deps_with_res_processing",
)

# Export of resources from transitive dep
starlark_process(
    name = "exports_other_lib",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    exports = [":resource_processing"],
)

exports_other_lib_resources_node = ExpectedResourcesNodeInfo(
    assets_symbols = "exports_other_lib_symbols/assets.bin",
    compiled_resources = "exports_other_lib_symbols/symbols.zip",
    label = ":exports_other_lib",
    manifest = "exports_other_lib_processed_manifest/AndroidManifest.xml",
    r_txt = "exports_other_lib_symbols/R.aapt2.txt",
)

starlark_process(
    name = "depends_on_exported_lib",
    deps = [":exports_other_lib"],
)

starlark_process_test(
    name = "test_depends_on_exported_lib",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [],
        transitive_assets = [
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "exports_other_lib_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "exports_other_lib_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
            exports_other_lib_resources_node,
        ],
    ),
    target_under_test = ":depends_on_exported_lib",
)

# Export a target that exports a target
starlark_process(
    name = "exports_other_lib_that_exports",
    exports = [":exports_other_lib"],
)

starlark_process_test(
    name = "test_exports_other_lib_that_exports",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            exports_other_lib_resources_node,
            resource_processing_resources_node,
        ],
        transitive_assets = [
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "exports_other_lib_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "exports_other_lib_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
            exports_other_lib_resources_node,
        ],
    ),
    target_under_test = ":exports_other_lib_that_exports",
)

# Dep and export with resources defined
starlark_process(
    name = "dep_and_export_with_resources",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    exports = [":another_resource_processing_lib"],
    deps = [":resource_processing"],
)

starlark_process_test(
    name = "test_dep_and_export_with_resources",
    expected_r_class_fields = [
        "dimen.activity_horizontal_margin",
        "string.string_bar",
        "string.my_string",
        "string.string_foo",
        "layout.activity",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets_symbols = "dep_and_export_with_resources_symbols/assets.bin",
                compiled_resources = "dep_and_export_with_resources_symbols/symbols.zip",
                label = ":dep_and_export_with_resources",
                manifest = "dep_and_export_with_resources_processed_manifest/AndroidManifest.xml",
                r_txt = "dep_and_export_with_resources_symbols/R.aapt2.txt",
            ),
            another_resource_processing_lib_resources_node,
        ],
        transitive_assets = [
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "dep_and_export_with_resources_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
            "another_resource_processing_lib_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "dep_and_export_with_resources_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
            "another_resource_processing_lib_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
            # This appears under transitives because exports behave as deps
            another_resource_processing_lib_resources_node,
        ],
    ),
    target_under_test = ":dep_and_export_with_resources",
)

# Dep and export with resources not defined
starlark_process(
    name = "dep_and_export_without_resources",
    exports = [":another_resource_processing_lib"],
    deps = [":resource_processing"],
)

starlark_process_test(
    name = "test_dep_and_export_without_resources",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [another_resource_processing_lib_resources_node],
        transitive_assets = [
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "resource_processing_symbols/assets.bin",
            "another_resource_processing_lib_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "resource_processing_symbols/symbols.zip",
            "another_resource_processing_lib_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            resource_processing_resources_node,
            # This appears under transitives because exports behave as deps
            another_resource_processing_lib_resources_node,
        ],
    ),
    target_under_test = ":dep_and_export_without_resources",
)

# Implicitly exported dep and normal export with fix_resource_transitivity disabled
starlark_process(
    name = "implicitly_exports_dep",
    fix_resource_transitivity = False,
    exports = [":another_resource_processing_lib"],
    deps = [":resource_processing"],
)

starlark_process_test(
    name = "test_implicitly_exports_dep",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            resource_processing_resources_node,
            another_resource_processing_lib_resources_node,
        ],
        transitive_assets = [
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "resource_processing_symbols/assets.bin",
            "another_resource_processing_lib_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "resource_processing_symbols/symbols.zip",
            "another_resource_processing_lib_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [],
    ),
    target_under_test = ":implicitly_exports_dep",
)

# Neverlinked target with "defined_resources" (from a manifest being present), deps, and exports.
# Currently neverlink only takes effect if resources are defined or
# ctx.fragments.android.fixed_resource_neverlinking is True.
starlark_process(
    name = "neverlink_with_manifest_and_exports",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    neverlink = 1,
    exports = [":resource_processing"],
    deps = [":another_resource_processing_lib"],  # Dep providers are not propagated due to neverlink
)

starlark_process_test(
    name = "test_neverlink_with_manifest_and_exports",
    expected_r_class_fields = [
        # Resource from dep
        "string.my_string",
        # Resources from export which is also treated as a dep
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = resource_processing_android_resources_info,
    target_under_test = ":neverlink_with_manifest_and_exports",
)

# Neverlinked target with assets, resources, and exports. Due to b/69668042, exports does not
# respect neverlink. This means that exported providers are propagated despite a target being
# neverlink. The neverlink target still avoids propagating its own primary asset/resource
# information.
starlark_process(
    name = "neverlink_with_resources_and_exports",
    assets = ["assets2/data/data.txt"],
    assets_dir = "assets2",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    neverlink = 1,
    resource_files = glob(["res_a/**"]),
    exports = [":resource_processing"],
)

starlark_process_test(
    name = "test_neverlink_with_resources_and_exports",
    expected_r_class_fields = [
        # Primary R class fields (":neverlink_with_resources_and_exports")
        "string.my_string",
        # R class fields from exported target (":resource_processing")
        "string.string_foo",
        "string.string_bar",
        "layout.activity",
        "dimen.activity_horizontal_margin",
        "dimen.activity_vertical_margin",
    ],
    expected_starlark_android_resources_info = resource_processing_android_resources_info,
    target_under_test = ":neverlink_with_resources_and_exports",
)

# Neverlinked target with deps, exports, and no resources
starlark_process(
    name = "neverlink_with_deps_and_exports",
    neverlink = 1,  # neverlink takes no effect because resources are not defined.
    exports = [":resource_processing"],
    deps = [":another_resource_processing_lib"],
)

starlark_process_test(
    name = "test_neverlink_with_deps_and_exports",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [resource_processing_resources_node],
        transitive_assets = [
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "another_resource_processing_lib_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "another_resource_processing_lib_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [
            another_resource_processing_lib_resources_node,
            resource_processing_resources_node,
        ],
    ),
    tags = ["manual"],
    target_under_test = ":neverlink_with_deps_and_exports",
)

# Neverlinked target with deps, exports, no resources, and fix_resource_transitivity disabled
starlark_process(
    name = "neverlink_with_deps_and_exports_disabled_transitivity_fix",
    fix_resource_transitivity = False,
    neverlink = 1,  # neverlink takes no effect because resources are not defined.
    exports = [":resource_processing"],
    deps = [":another_resource_processing_lib"],
)

starlark_process_test(
    name = "test_neverlink_with_deps_and_exports_disabled_transitivity_fix",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            another_resource_processing_lib_resources_node,  # Implicitly exported
            resource_processing_resources_node,
        ],
        transitive_assets = [
            "assets/some_asset.txt",
        ],
        transitive_assets_symbols = [
            "another_resource_processing_lib_symbols/assets.bin",
            "resource_processing_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "another_resource_processing_lib_symbols/symbols.zip",
            "resource_processing_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [],
    ),
    tags = ["manual"],
    target_under_test = ":neverlink_with_deps_and_exports_disabled_transitivity_fix",
)

starlark_process(
    name = "databinding_enabled",
    custom_package = "test.rules.resources",
    enable_data_binding = 1,
    manifest = "AndroidManifest.xml",
    resource_files = glob(["databinding_res/**"]),
)

starlark_process_test(
    name = "test_databinding_enabled",
    expected_r_class_fields = [
        "id.text",
        "layout.category",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets_symbols =
                    "databinding_enabled_symbols/assets.bin",
                compiled_resources =
                    "fixed/databinding_enabled_symbols/symbols.zip",
                label = ":databinding_enabled",
                manifest =
                    "databinding_enabled_processed_manifest/AndroidManifest.xml",
                r_txt = "databinding_enabled_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets_symbols = [
            "databinding_enabled_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "fixed/databinding_enabled_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [],
    ),
    target_under_test = ":databinding_enabled",
)

starlark_process(
    name = "databinding_res_with_databinding_disabled",
    custom_package = "test.rules.resources",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["databinding_res/**"]),
)

starlark_process_test(
    name = "test_databinding_res_with_databinding_disabled",
    expected_r_class_fields = [
        "id.text",
        "layout.category",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets_symbols =
                    "databinding_res_with_databinding_disabled_symbols/assets.bin",
                compiled_resources =
                    "databinding_res_with_databinding_disabled_symbols/symbols.zip",
                label = ":databinding_res_with_databinding_disabled",
                manifest = "databinding_res_with_databinding_disabled_processed_manifest/AndroidManifest.xml",
                r_txt =
                    "databinding_res_with_databinding_disabled_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets_symbols = [
            "databinding_res_with_databinding_disabled_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "databinding_res_with_databinding_disabled_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [],
    ),
    target_under_test = ":databinding_res_with_databinding_disabled",
)

# Databinding with genfile resources.

genrule(
    name = "generated_resources",
    srcs = ["databinding_res/res/layout/category.xml"],
    outs = ["gen_databinding_res/res/layout/category.xml"],
    cmd = """#!/bin/bash
cp $< $@
""",
)

starlark_process(
    name = "databinding_with_generated_resources",
    custom_package = "test.rules.resources",
    enable_data_binding = 1,
    manifest = "AndroidManifest.xml",
    resource_files = [":generated_resources"],
)

starlark_process_test(
    name = "test_databinding_with_generated_resources",
    expected_r_class_fields = [
        "id.text",
        "layout.category",
    ],
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets_symbols = "databinding_with_generated_resources_symbols/assets.bin",
                compiled_resources = "fixed/databinding_with_generated_resources_symbols/symbols.zip",
                label = ":databinding_with_generated_resources",
                manifest = "databinding_with_generated_resources_processed_manifest/AndroidManifest.xml",
                r_txt =
                    "databinding_with_generated_resources_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets_symbols = [
            "databinding_with_generated_resources_symbols/assets.bin",
        ],
        transitive_compiled_resources = [
            "fixed/databinding_with_generated_resources_symbols/symbols.zip",
        ],
        transitive_resources_nodes = [],
    ),
    target_under_test = ":databinding_with_generated_resources",
)

# Failure test with resources but no manifest
starlark_process(
    name = "res_without_manifest",
    resource_files = glob(["res/**"]),
    tags = [
        "manual",
        "negative_test",
        "nobuilder",
    ],
)

failure_test(
    name = "test_res_without_manifest",
    target_under_test = ":res_without_manifest",
)

# Failure test when stamp manifest but no java package
starlark_process(
    name = "stamping_manifest_without_java_package",
    stamp_manifest = True,
    tags = [
        "manual",
        "negative_test",
        "nobuilder",
    ],
    use_java_package = False,
)

failure_test(
    name = "test_stamping_manifest_without_java_package",
    target_under_test = ":stamping_manifest_without_java_package",
)

starlark_process(
    name = "with_xsltproc_and_instrument_xslt_specified",
    manifest = "AndroidManifest.xml",
    use_instrument_xslt = True,
    use_xsltproc = True,
)

starlark_process_test(
    name = "test_with_xsltproc_and_instrument_xslt_specified",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets_symbols = "with_xsltproc_and_instrument_xslt_specified_symbols/assets.bin",
                compiled_resources = "with_xsltproc_and_instrument_xslt_specified_symbols/symbols.zip",
                label = ":with_xsltproc_and_instrument_xslt_specified",
                manifest = "with_xsltproc_and_instrument_xslt_specified_processed_manifest/AndroidManifest.xml",
                r_txt = "with_xsltproc_and_instrument_xslt_specified_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets_symbols = ["with_xsltproc_and_instrument_xslt_specified_symbols/assets.bin"],
        transitive_compiled_resources = ["with_xsltproc_and_instrument_xslt_specified_symbols/symbols.zip"],
    ),
    target_under_test = ":with_xsltproc_and_instrument_xslt_specified",
)

starlark_process(
    name = "without_xsltproc_and_instrument_xslt_specified",
    manifest = "AndroidManifest.xml",
    use_instrument_xslt = False,
    use_xsltproc = False,
)

starlark_process_test(
    name = "test_without_xsltproc_and_instrument_xslt_specified",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            ExpectedResourcesNodeInfo(
                assets_symbols = "without_xsltproc_and_instrument_xslt_specified_symbols/assets.bin",
                compiled_resources = "without_xsltproc_and_instrument_xslt_specified_symbols/symbols.zip",
                label = ":without_xsltproc_and_instrument_xslt_specified",
                manifest = "without_xsltproc_and_instrument_xslt_specified_processed_manifest/AndroidManifest.xml",
                r_txt = "without_xsltproc_and_instrument_xslt_specified_symbols/R.aapt2.txt",
            ),
        ],
        transitive_assets_symbols = ["without_xsltproc_and_instrument_xslt_specified_symbols/assets.bin"],
        transitive_compiled_resources = ["without_xsltproc_and_instrument_xslt_specified_symbols/symbols.zip"],
    ),
    target_under_test = ":without_xsltproc_and_instrument_xslt_specified",
)

# Failure when xsltproc is specified without instrument_xslt.
starlark_process(
    name = "xsltproc_without_instrument_xslt_specified",
    manifest = "AndroidManifest.xml",
    tags = [
        "manual",
        "negative_test",
        "nobuilder",
    ],
    use_instrument_xslt = False,
    use_xsltproc = True,
)

failure_test(
    name = "test_xsltproc_without_instrument_xslt_specified",
    expected_error_msg = "Error, both instrument_xslt and xsltproc",
    target_under_test = ":xsltproc_without_instrument_xslt_specified",
)

# Failure when instrument_xsl is specified without xsltproc.
starlark_process(
    name = "instrument_xslt_without_xsltproc_specified",
    manifest = "AndroidManifest.xml",
    tags = [
        "manual",
        "negative_test",
        "nobuilder",
    ],
    use_instrument_xslt = True,
    use_xsltproc = False,
)

failure_test(
    name = "test_instrument_xslt_without_xsltproc_specified",
    expected_error_msg = "Error, both instrument_xslt and xsltproc",
    target_under_test = ":instrument_xslt_without_xsltproc_specified",
)

# Triangle-shaped dependency graph where manifest_without_resources is both direct
# and transitive for exports_manifest_without_resources because of
# depends_on_manifest_without_resources
starlark_process(
    name = "manifest_without_resources",
    manifest = "AndroidManifest.xml",
)

manifest_without_resources_resources_node = ExpectedResourcesNodeInfo(
    assets_symbols = "manifest_without_resources_symbols/assets.bin",
    compiled_resources = "manifest_without_resources_symbols/symbols.zip",
    label = ":manifest_without_resources",
    manifest = "manifest_without_resources_processed_manifest/AndroidManifest.xml",
    r_txt = "manifest_without_resources_symbols/R.aapt2.txt",
)

starlark_process_test(
    name = "test_manifest_without_resources",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [manifest_without_resources_resources_node],
        transitive_assets_symbols = ["manifest_without_resources_symbols/assets.bin"],
        transitive_compiled_resources = ["manifest_without_resources_symbols/symbols.zip"],
    ),
    target_under_test = ":manifest_without_resources",
)

starlark_process(
    name = "depends_on_manifest_without_resources",
    deps = [":manifest_without_resources"],
)

starlark_process(
    name = "exports_manifest_without_resources",
    exports = [
        ":depends_on_manifest_without_resources",
        ":manifest_without_resources",
    ],
)

starlark_process_test(
    name = "test_exports_manifest_without_resources",
    expected_starlark_android_resources_info = ExpectedStarlarkAndroidResourcesInfo(
        direct_resources_nodes = [
            manifest_without_resources_resources_node,
        ],
        transitive_assets_symbols = ["manifest_without_resources_symbols/assets.bin"],
        transitive_compiled_resources = ["manifest_without_resources_symbols/symbols.zip"],
        transitive_resources_nodes = [
            manifest_without_resources_resources_node,
        ],
    ),
    inspect_actions = dict(
        PackageAndroidResources = [
            "--data",
            ":".join([
                "",
                "",
                "bazel-out/k8-fastbuild/bin/test/rules/resources/manifest_without_resources_processed_manifest/AndroidManifest.xml",
                "bazel-out/k8-fastbuild/bin/test/rules/resources/manifest_without_resources_symbols/R.aapt2.txt",
                "bazel-out/k8-fastbuild/bin/test/rules/resources/manifest_without_resources_symbols/symbols.zip",
            ]),
            "--directData",
            ":".join([
                "",
                "",
                "bazel-out/k8-fastbuild/bin/test/rules/resources/manifest_without_resources_processed_manifest/AndroidManifest.xml",
                "bazel-out/k8-fastbuild/bin/test/rules/resources/manifest_without_resources_symbols/R.aapt2.txt",
                "bazel-out/k8-fastbuild/bin/test/rules/resources/manifest_without_resources_symbols/symbols.zip",
            ]),
            "--primaryData",
            ":".join([
                "",
                "",
                "bazel-out/k8-fastbuild/bin/test/rules/resources/_generated/exports_manifest_without_resources/AndroidManifest.xml",
                "",
                "",
            ]),
        ],
    ),
    target_under_test = ":exports_manifest_without_resources",
)

# Failure test with wrong resources
starlark_process(
    name = "resource_processing_with_wrong_res_type",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["bad_res/**"]),
    tags = [
        "manual",
        "nobuilder",
    ],
)

failure_test(
    name = "test_resource_processing_with_wrong_res_type",
    target_under_test = ":resource_processing_with_wrong_res_type",
)

resources_package(
    name = "resource_package_no_res",
    manifest = "merge_binary_manifests/manifest_values/AndroidManifest.xml",
    manifest_values = {
        "main_activity_name": ".MainActivity",
    },
)

resources_package_test(
    name = "test_resource_package_no_res",
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
    ],
    expected_manifest = "merge_binary_manifests/manifest_values/ExpectedAndroidManifest.xml",
    deps = [":resource_package_no_res"],
)

# Test no resources with a single dep
resources_package(
    name = "resource_package_no_res_with_dep",
    custom_package = "com.google.app",
    manifest = "merge_binary_manifests/no_manifest_values/AndroidManifest.xml",
    deps = [":resource_processing"],
)

resources_package_test(
    name = "test_resource_package_no_res_with_dep",
    expected_assets = [
        "assets/some_asset.txt",
    ],
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$dimen.class",
        "com/google/app/R$layout.class",
        "com/google/app/R$string.class",
        "com/google/app/R.class",
        "test/rules/resources/R$dimen.class",
        "test/rules/resources/R$layout.class",
        "test/rules/resources/R$string.class",
        "test/rules/resources/R.class",
    ],
    expected_res = [
        "string/string_foo",
        "string/string_bar",
        "layout/activity",
        "dimen/activity_horizontal_margin",
        "dimen/activity_vertical_margin",
    ],
    deps = [":resource_package_no_res_with_dep"],
)

# Test with resources and a single dep
resources_package(
    name = "resource_package_with_res_and_dep",
    assets = ["assets2/data/data.txt"],
    assets_dir = "assets2",
    custom_package = "com.google.app",
    manifest = "merge_binary_manifests/no_manifest_values/AndroidManifest.xml",
    resource_files = glob(["res_a/**"]),
    deps = [":resource_processing"],
)

resources_package_test(
    name = "test_resource_package_with_res_and_dep",
    expected_assets = [
        "assets/some_asset.txt",
        "assets/data/data.txt",
    ],
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$dimen.class",
        "com/google/app/R$layout.class",
        "com/google/app/R$string.class",
        "com/google/app/R.class",
        "test/rules/resources/R$dimen.class",
        "test/rules/resources/R$layout.class",
        "test/rules/resources/R$string.class",
        "test/rules/resources/R.class",
    ],
    expected_res = [
        "string/my_string",
        "string/string_foo",
        "string/string_bar",
        "layout/activity",
        "dimen/activity_horizontal_margin",
        "dimen/activity_vertical_margin",
    ],
    deps = [":resource_package_with_res_and_dep"],
)

# Test with resources and a single dep with exports
resources_package(
    name = "resource_package_with_res_and_dep_with_export",
    assets = ["assets2/data/data.txt"],
    assets_dir = "assets2",
    custom_package = "com.google.app",
    manifest = "merge_binary_manifests/no_manifest_values/AndroidManifest.xml",
    resource_files = glob(["res_a/**"]),
    deps = [":exports_other_lib"],
)

resources_package_test(
    name = "test_resource_package_with_res_and_dep_with_export",
    expected_assets = [
        "assets/some_asset.txt",
        "assets/data/data.txt",
    ],
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$dimen.class",
        "com/google/app/R$layout.class",
        "com/google/app/R$string.class",
        "com/google/app/R.class",
        "test/rules/resources/R$dimen.class",
        "test/rules/resources/R$layout.class",
        "test/rules/resources/R$string.class",
        "test/rules/resources/R.class",
    ],
    expected_res = [
        "string/my_string",
        "string/string_foo",
        "string/string_bar",
        "layout/activity",
        "dimen/activity_horizontal_margin",
        "dimen/activity_vertical_margin",
    ],
    deps = [":resource_package_with_res_and_dep_with_export"],
)

# Test with resources and a single dep with neverlink
resources_package(
    name = "resource_package_with_res_and_neverlink_dep_that_exports",
    custom_package = "com.google.app",
    manifest = "merge_binary_manifests/no_manifest_values/AndroidManifest.xml",
    deps = [":neverlink_with_resources_and_exports"],
)

resources_package_test(
    name = "test_resource_package_with_res_and_neverlink_dep_that_exports",
    expected_assets = [
        "assets/some_asset.txt",
    ],
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$dimen.class",
        "com/google/app/R$layout.class",
        "com/google/app/R$string.class",
        "com/google/app/R.class",
        "test/rules/resources/R$dimen.class",
        "test/rules/resources/R$layout.class",
        "test/rules/resources/R$string.class",
        "test/rules/resources/R.class",
    ],
    expected_res = [
        "string/string_foo",
        "string/string_bar",
        "layout/activity",
        "dimen/activity_horizontal_margin",
        "dimen/activity_vertical_margin",
    ],
    deps = [":resource_package_with_res_and_neverlink_dep_that_exports"],
)

# Test with resources and a single dep with strict deps disabled
resources_package(
    name = "resource_package_with_res_and_dep_without_strict_deps",
    custom_package = "com.google.app",
    manifest = "merge_binary_manifests/no_manifest_values/AndroidManifest.xml",
    deps = [":no_strict_deps_has_direct_and_transitive_dependencies"],
)

resources_package_test(
    name = "test_resource_package_with_res_and_dep_without_strict_deps",
    expected_assets = [
        "assets/some_asset.txt",
    ],
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$dimen.class",
        "com/google/app/R$layout.class",
        "com/google/app/R$string.class",
        "com/google/app/R.class",
        "test/rules/resources/R$dimen.class",
        "test/rules/resources/R$layout.class",
        "test/rules/resources/R$string.class",
        "test/rules/resources/R.class",
    ],
    expected_res = [
        "string/my_string",
        "string/strict_deps",
        "string/my_other_string",
        "string/string_foo",
        "string/string_bar",
        "layout/activity",
        "dimen/activity_horizontal_margin",
        "dimen/activity_vertical_margin",
    ],
    deps = [":resource_package_with_res_and_dep_without_strict_deps"],
)

# Test with resources and multiple deps
resources_package(
    name = "resource_package_with_res_and_multiple_dep",
    custom_package = "com.google.app",
    manifest = "merge_binary_manifests/no_manifest_values/AndroidManifest.xml",
    resource_files = glob(["res_c/**"]),
    deps = [
        ":another_resource_processing_lib",
        ":resource_processing",
        ":resources_with_dep_with_res",
    ],
)

resources_package_test(
    name = "test_resource_package_with_res_and_multiple_deps",
    expected_assets = [
        "assets/some_asset.txt",
    ],
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$dimen.class",
        "com/google/app/R$layout.class",
        "com/google/app/R$string.class",
        "com/google/app/R.class",
        "test/rules/resources/R$dimen.class",
        "test/rules/resources/R$layout.class",
        "test/rules/resources/R$string.class",
        "test/rules/resources/R.class",
    ],
    expected_res = [
        "string/my_string",
        "string/my_other_string",
        "string/string_foo",
        "string/string_bar",
        "layout/activity",
        "dimen/activity_horizontal_margin",
        "dimen/activity_vertical_margin",
    ],
    deps = [":resource_package_with_res_and_multiple_dep"],
)

resources_package(
    name = "resource_package_res_and_assets",
    assets = glob(["assets/**"]),
    assets_dir = "assets",
    custom_package = "com.google.app",
    manifest = "merge_binary_manifests/manifest_values/AndroidManifest.xml",
    manifest_values = {
        "main_activity_name": ".MainActivity",
        "applicationId": "com.google.with.application.id",
    },
    resource_files = glob(["res/**"]),
)

resources_package_test(
    name = "test_resource_package_res_and_assets",
    expected_assets = [
        "assets/some_asset.txt",
    ],
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$dimen.class",
        "com/google/app/R$layout.class",
        "com/google/app/R$string.class",
        "com/google/app/R.class",
    ],
    expected_manifest = "merge_binary_manifests/manifest_values/ExpectedAndroidManifestWithApplicationId.xml",
    expected_res = [
        "dimen/activity_horizontal_margin",
        "dimen/activity_vertical_margin",
        "layout/activity",
        "string/string_bar",
        "string/string_foo",
    ],
    deps = [":resource_package_res_and_assets"],
)

resources_package(
    name = "resource_package_databinding_res",
    custom_package = "com.google.app",
    enable_data_binding = 1,
    manifest = "AndroidManifest.xml",
    resource_files = glob(["databinding_res/**"]),
)

resources_package_test(
    name = "test_resource_package_databinding_res",
    expect_databinding_enabled = 1,
    expected_is_debuggable = False,
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$id.class",
        "com/google/app/R$layout.class",
        "com/google/app/R.class",
    ],
    expected_res = [
        "id/text",
        "layout/category",
    ],
    deps = [":resource_package_databinding_res"],
)

resources_package(
    name = "resource_package_with_databinding_dep",
    custom_package = "com.google.app",
    manifest = "AndroidManifest.xml",
    deps = [":databinding_enabled"],
)

resources_package_test(
    name = "test_resource_package_with_databinding_dep",
    expected_is_debuggable = False,
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$id.class",
        "com/google/app/R$layout.class",
        "com/google/app/R.class",
        "test/rules/resources/R$id.class",
        "test/rules/resources/R$layout.class",
        "test/rules/resources/R.class",
    ],
    expected_res = [
        "id/text",
        "layout/category",
    ],
    deps = [":resource_package_with_databinding_dep"],
)

resources_package(
    name = "resource_package_version_code_and_name",
    custom_package = "com.google.app",
    manifest = "merge_binary_manifests/manifest_values/AndroidManifest.xml",
    manifest_values = {
        "main_activity_name": ".MainActivity",
        "versionCode": "1",
        "versionName": "vers",
    },
)

resources_package_test(
    name = "test_resource_package_version_code_and_name",
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
    ],
    expected_manifest = "merge_binary_manifests/manifest_values/ExpectedWithVersionStampsAndroidManifest.xml",
    deps = [":resource_package_version_code_and_name"],
)

resources_package(
    name = "resource_package_with_application_compilation_mode_dbg",
    compilation_mode = "dbg",
    manifest = "compilation_mode/AndroidManifest_with_application.xml",
)

resources_package_test(
    name = "test_resource_package_with_application_compilation_mode_dbg",
    expected_is_debuggable = True,
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
    ],
    deps = [":resource_package_with_application_compilation_mode_dbg"],
)

resources_package(
    name = "resource_package_with_application_compilation_mode_fastbuild",
    compilation_mode = "fastbuild",
    manifest = "compilation_mode/AndroidManifest_with_application.xml",
)

resources_package_test(
    name = "test_resource_package_with_application_compilation_mode_fastbuild",
    expected_is_debuggable = True,
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
    ],
    deps = [":resource_package_with_application_compilation_mode_fastbuild"],
)

resources_package(
    name = "resource_package_with_application_compilation_mode_opt",
    compilation_mode = "opt",
    manifest = "compilation_mode/AndroidManifest_with_application.xml",
)

resources_package_test(
    name = "test_resource_package_with_application_compilation_mode_opt",
    expected_is_debuggable = False,
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
    ],
    deps = [":resource_package_with_application_compilation_mode_opt"],
)

resources_package(
    name = "resource_package_without_application_compilation_mode_dbg",
    compilation_mode = "dbg",
    manifest = "compilation_mode/AndroidManifest_without_application.xml",
)

resources_package_test(
    name = "test_resource_package_without_application_compilation_mode_dbg",
    expected_is_debuggable = False,
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
    ],
    deps = [":resource_package_without_application_compilation_mode_dbg"],
)

resources_package(
    name = "resource_package_without_application_compilation_mode_fastbuild",
    compilation_mode = "fastbuild",
    manifest = "compilation_mode/AndroidManifest_without_application.xml",
)

resources_package_test(
    name = "test_resource_package_without_application_compilation_mode_fastbuild",
    expected_is_debuggable = False,
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
    ],
    deps = [":resource_package_without_application_compilation_mode_fastbuild"],
)

resources_package(
    name = "resource_package_without_application_compilation_mode_opt",
    compilation_mode = "opt",
    manifest = "compilation_mode/AndroidManifest_without_application.xml",
)

resources_package_test(
    name = "test_resource_package_without_application_compilation_mode_opt",
    expected_is_debuggable = False,
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
    ],
    deps = [":resource_package_without_application_compilation_mode_opt"],
)

# Failure test with wrong resources
resources_package(
    name = "resource_package_with_wrong_res_type",
    manifest = "AndroidManifest.xml",
    resource_files = glob(["bad_res/**"]),
    tags = [
        "manual",
        "nobuilder",
    ],
)

failure_test(
    name = "test_resource_package_with_wrong_res_type",
    target_under_test = ":resource_package_with_wrong_res_type",
)

# Test with resources and multiple deps with legacy manifest merger
resources_package(
    name = "resource_package_with_res_and_multiple_dep_and_legacy_manifest_merger",
    custom_package = "com.google.app",
    manifest = "merge_binary_manifests/no_manifest_values/AndroidManifest.xml",
    resource_files = glob(["res_c/**"]),
    use_legacy_manifest_merger = True,
    deps = [
        ":another_resource_processing_lib",
        ":resource_processing",
        ":resources_with_dep_with_res",
    ],
)

resources_package_test(
    name = "test_resource_package_with_res_and_multiple_deps_and_legacy_manifest_merger",
    expected_assets = [
        "assets/some_asset.txt",
    ],
    expected_jar_files = [
        "META-INF/",
        "META-INF/MANIFEST.MF",
        "com/google/app/R$dimen.class",
        "com/google/app/R$layout.class",
        "com/google/app/R$string.class",
        "com/google/app/R.class",
        "test/rules/resources/R$dimen.class",
        "test/rules/resources/R$layout.class",
        "test/rules/resources/R$string.class",
        "test/rules/resources/R.class",
    ],
    expected_res = [
        "string/my_string",
        "string/my_other_string",
        "string/string_foo",
        "string/string_bar",
        "layout/activity",
        "dimen/activity_horizontal_margin",
        "dimen/activity_vertical_margin",
    ],
    deps = [":resource_package_with_res_and_multiple_dep_and_legacy_manifest_merger"],
)

# Test multi cpu configration filtering
foo_x86 = FakeSplitTransitionTarget(
    cpu_configuration = "x86",
    label = "//a/b:foo",
)

foo_arm = FakeSplitTransitionTarget(
    cpu_configuration = "arm",
    label = "//a/b:foo",
)

bar_x86 = FakeSplitTransitionTarget(
    cpu_configuration = "x86",
    label = "//a/b:bar",
)

bar_arm = FakeSplitTransitionTarget(
    cpu_configuration = "arm",
    label = "//a/b:bar",
)

filter_multi_cpu_configuration_targets_test(
    name = "test_filtering_with_single_cpu",
    expected_filtered_split_targets = [
        foo_x86,
        bar_x86,
    ],
    split_targets = [
        foo_x86,
        bar_x86,
    ],
)

filter_multi_cpu_configuration_targets_test(
    name = "test_filtering_with_multiple_cpus",
    expected_filtered_split_targets = [
        foo_x86,
        bar_x86,
    ],
    split_targets = [
        foo_x86,
        foo_arm,
        bar_x86,
        bar_arm,
    ],
)

resources_package(
    name = "resource_package_with_res_and_multiple_dep_and_instruments",
    custom_package = "com.google.app",
    instruments = ":resource_package_with_res_and_multiple_dep",
    manifest = "merge_binary_manifests/no_manifest_values/AndroidManifest.xml",
    resource_files = glob(["res_c/**"]),
    deps = [
        ":another_resource_processing_lib",
        ":resource_processing",
        ":resources_with_dep_with_res",
    ],
)

package_resources_final_id_test(
    name = "package_resources_nonfinal_id",
    final = False,
    target_under_test = ":resource_package_with_res_and_multiple_dep_and_instruments",
)

package_resources_final_id_test(
    name = "package_resources_final_id",
    final = True,
    target_under_test = ":resource_package_with_res_and_multiple_dep",
)
