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
"""Test rule for resource processing."""

load("//providers:providers.bzl", "StarlarkAndroidResourcesInfo")
load("//rules:attrs.bzl", "ANDROID_BINARY_ATTRS")
load("//rules:common.bzl", _common = "common")
load("//rules:java.bzl", _java = "java")
load("//rules:resources.bzl", _resources = "resources", _resources_testing = "testing")
load(
    "//rules:utils.bzl",
    "ANDROID_SDK_TOOLCHAIN_TYPE",
    "get_android_sdk",
    "get_android_toolchain",
    _compilation_mode = "compilation_mode",
    _utils = "utils",
)
load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(
    "//test/utils:asserts.bzl",
    _asserts = "asserts",
)
load("@rules_java//java/common:java_common.bzl", "java_common")
load(
    "@bazel_skylib//lib:unittest.bzl",
    "analysistest",
    "asserts",
    "unittest",
)
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

visibility(PROJECT_VISIBILITY)

_StarlarkResourcesTestingInfo = provider()

def _starlark_process_impl(ctx):
    java_package = _java.resolve_package_from_label(ctx.label, ctx.attr.custom_package)
    starlark_resources_ctx = _resources.process_starlark(
        ctx,
        java_package = java_package if ctx.attr.use_java_package else None,
        manifest = ctx.file.manifest,
        assets = ctx.files.assets,
        assets_dir = ctx.attr.assets_dir,
        deps = ctx.attr.deps,
        exports = ctx.attr.exports,
        resource_files = ctx.files.resource_files,
        stamp_manifest = ctx.attr.stamp_manifest,
        neverlink = ctx.attr.neverlink,
        enable_data_binding = ctx.attr.enable_data_binding,
        fix_resource_transitivity = ctx.attr.fix_resource_transitivity,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
        android_jar = get_android_sdk(ctx).android_jar,
        android_kit = get_android_toolchain(ctx).android_kit.files_to_run,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        java_toolchain = _common.get_java_toolchain(ctx),
        host_javabase = _common.get_host_javabase(ctx),
        instrument_xslt =
            _utils.only(get_android_toolchain(ctx).add_g3itr_xslt.files.to_list()) if ctx.attr.use_xsltproc else None,
        xsltproc =
            get_android_toolchain(ctx).xsltproc_tool.files_to_run if ctx.attr.use_instrument_xslt else None,
        zip_tool = get_android_toolchain(ctx).zip_tool.files_to_run,
    )

    validation_results = starlark_resources_ctx["validation_results"]
    if starlark_resources_ctx["resources_apk"]:
        validation_results.append(starlark_resources_ctx["resources_apk"])

    return starlark_resources_ctx["providers"] + [
        OutputGroupInfo(_validation = validation_results),
        _StarlarkResourcesTestingInfo(
            r_java = starlark_resources_ctx["r_java"],
        ),
    ]

starlark_process = rule(
    implementation = _starlark_process_impl,
    attrs = dict(
        stamp_manifest = attr.bool(
            default = True,
        ),
        use_java_package = attr.bool(
            default = True,
        ),
        assets = attr.label_list(
            allow_files = True,
        ),
        assets_dir = attr.string(),
        manifest = attr.label(
            allow_single_file = [".xml"],
        ),
        neverlink = attr.bool(),
        enable_data_binding = attr.bool(),
        custom_package = attr.string(),
        resource_files = attr.label_list(
            allow_files = True,
        ),
        deps = attr.label_list(
            allow_rules = [
                "starlark_process",
            ],
        ),
        exports = attr.label_list(
            allow_rules = [
                "starlark_process",
            ],
        ),
        fix_resource_transitivity = attr.bool(default = True),
        _host_javabase = attr.label(
            cfg = "exec",
            default = Label("//tools/jdk:current_java_runtime"),
        ),
        _java_toolchain = attr.label(
            default = Label("//tools/jdk:toolchain_android_only"),
        ),
        _manifest_merge_order = attr.label(
            default = "//rules/flags:manifest_merge_order",
        ),
        use_xsltproc = attr.bool(default = True),
        use_instrument_xslt = attr.bool(default = True),
    ),
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
        ANDROID_SDK_TOOLCHAIN_TYPE,
    ],
    fragments = [
        "android",
        "bazel_android",  # NOTE: Only exists for Bazel.
    ],
    provides = [_StarlarkResourcesTestingInfo],
    _skylark_testable = True,
)

def _starlark_process_test_impl(ctx):
    if ctx.attr.expected_starlark_android_resources_info:
        if StarlarkAndroidResourcesInfo not in ctx.attr.target_under_test:
            fail("StarlarkAndroidResourcesInfo was expected but not provided")
        _asserts.provider.starlark_android_resources_info(
            ctx.attr.expected_starlark_android_resources_info[StarlarkAndroidResourcesInfo],
            ctx.attr.target_under_test[StarlarkAndroidResourcesInfo],
            ctx.attr.target_under_test.label,
        )
    elif StarlarkAndroidResourcesInfo in ctx.attr.target_under_test:
        fail("Expected no StarlarkAndroidResourcesInfo, but the provider was found")

    _asserts.actions.check_actions(
        ctx.attr.inspect_actions,
        ctx.attr.target_under_test[Actions],
    )

    r_java = ctx.attr.target_under_test[_StarlarkResourcesTestingInfo].r_java
    runfiles = []
    java = None
    args = dict(
        package = ctx.attr.target_under_test.label.package,
        expected_r_class_fields = ",".join(ctx.attr.expected_r_class_fields),
        check_r_java = r_java != None,
        java = "",
        class_path = "",
        r_jar_path = "",
    )

    if r_java:
        args["r_jar_path"] = _utils.only(r_java.runtime_output_jars).short_path
        args["class_path"] = ":".join(
            [args["r_jar_path"], ctx.executable._r_class_check.short_path],
        )
        runfiles = r_java.runtime_output_jars + [ctx.executable._r_class_check]
        java = ctx.attr._host_javabase[java_common.JavaRuntimeInfo]
        args["java"] = java.java_executable_exec_path

    elif ctx.attr.expected_r_class_fields:
        fail("Expected a R.java file but none was generated")

    test = ctx.actions.declare_file(ctx.label.name + "/test.sh")
    ctx.actions.write(
        test,
        """#!/bin/bash
set -eu

EXPECTED_R_CLASS_FIELDS="{expected_r_class_fields}"
if [ "{check_r_java}" == "True" ]; then

    # Check the contents of the resources jar, as it is always produced.
    # There are cases when it is produced empty (with only META-INF data).
    # If there is no R.class generated and the expectation is no resource
    # ids, then pass.
    set +e  # grep may return non zero exit code.
    R_JAR_CONTENT="$(unzip -Z1 {r_jar_path} | grep -v 'META-INF')"
    set -e
    # If the R.jar is empty and expectation is None. Pass.
    if [ "${{R_JAR_CONTENT}}" == "" ] && \
        [ "${{EXPECTED_R_CLASS_FIELDS}}" == "" ]; then
        exit
    fi

    {java} -cp {class_path} com.google.RClassChecker \
        --package="{package}" \
        --expected_r_class_fields="${{EXPECTED_R_CLASS_FIELDS}}"
fi
        """.format(**args),
        is_executable = True,
    )
    return DefaultInfo(
        executable = test,
        runfiles = ctx.runfiles(
            files = runfiles,
            transitive_files = java.files if java else None,
        ),
    )

starlark_process_test = rule(
    implementation = _starlark_process_test_impl,
    attrs = dict(
        _asserts.provider.attrs.items() + _asserts.r_class.attrs.items() + _asserts.actions.attrs.items(),
        target_under_test = attr.label(),
        _java_toolchain = attr.label(
            cfg = "exec",
            default = Label("//tools/jdk:toolchain_android_only"),
        ),
        _host_javabase = attr.label(
            cfg = "exec",
            default = Label("//tools/jdk:current_java_runtime"),
        ),
    ),
    fragments = ["java"],
    test = True,
)

_FakeSplitTransitionTargetInfo = provider(
    "Fake Split Transition Target object",
    fields = dict(
        label = "The target label",
        cpu_configuration = "The CPU configuration",
    ),
)

def _fake_split_transition_target_impl(ctx):
    return [
        _FakeSplitTransitionTargetInfo(
            label = ctx.attr.label,
            cpu_configuration = ctx.attr.cpu_configuration,
        ),
    ]

_fake_split_transition_target = rule(
    implementation = _fake_split_transition_target_impl,
    attrs = dict(
        label = attr.string(),
        cpu_configuration = attr.string(),
    ),
)

def FakeSplitTransitionTarget(
        label,
        cpu_configuration,
        name = "ignored"):  # appease linter
    name = label + cpu_configuration
    name = ":" + "".join([c for c in name.elems() if c not in [":", "/"]])

    _fake_split_transition_target(
        name = name[1:],
        label = label,
        cpu_configuration = cpu_configuration,
    )
    return name

def _filter_multi_cpu_configuration_targets_test_impl(ctx):
    env = unittest.begin(ctx)
    expected_filtered_split_targets = [
        t[_FakeSplitTransitionTargetInfo]
        for t in ctx.attr.expected_filtered_split_targets
    ]
    split_targets = [t[_FakeSplitTransitionTargetInfo] for t in ctx.attr.split_targets]
    asserts.equals(
        env,
        expected_filtered_split_targets,
        _resources_testing.filter_multi_cpu_configuration_targets(split_targets),
    )
    return unittest.end(env)

filter_multi_cpu_configuration_targets_test = unittest.make(
    impl = _filter_multi_cpu_configuration_targets_test_impl,
    attrs = dict(
        split_targets = attr.label_list(),
        expected_filtered_split_targets = attr.label_list(),
    ),
)

def _resources_package_impl(ctx):
    java_package = _java.resolve_package_from_label(
        ctx.label,
        ctx.attr.custom_package,
    )
    packaged_resources_ctx = _resources.package(
        ctx,
        assets = ctx.files.assets,
        assets_dir = ctx.attr.assets_dir,
        resource_files = ctx.files.resource_files,
        manifest = ctx.file.manifest,
        manifest_values = ctx.attr.manifest_values,
        manifest_merge_order = ctx.attr._manifest_merge_order[BuildSettingInfo].value,
        instruments = ctx.attr.instruments,
        java_package = java_package,
        compilation_mode = ctx.attr.compilation_mode,
        use_legacy_manifest_merger = ctx.attr.use_legacy_manifest_merger,
        deps = ctx.attr.deps,
        enable_data_binding = ctx.attr.enable_data_binding,
        aapt = get_android_toolchain(ctx).aapt2.files_to_run,
        android_jar = get_android_sdk(ctx).android_jar,
        legacy_merger = ctx.attr._legacy_merger.files_to_run,
        xsltproc = ctx.attr._xsltproc_tool.files_to_run,
        instrument_xslt = ctx.file._add_g3itr_xslt,
        busybox = get_android_toolchain(ctx).android_resources_busybox.files_to_run,
        host_javabase = ctx.attr._host_javabase,
    )

    return [packaged_resources_ctx] + packaged_resources_ctx.providers

resources_package = rule(
    implementation = _resources_package_impl,
    attrs = dict(
        assets = attr.label_list(
            allow_files = True,
        ),
        assets_dir = attr.string(),
        manifest = attr.label(
            allow_single_file = [".xml"],
        ),
        enable_data_binding = attr.bool(),
        instruments = attr.label(),
        manifest_values = attr.string_dict(),
        custom_package = attr.string(),
        resource_files = attr.label_list(
            allow_files = True,
        ),
        compilation_mode = attr.string(
            default = _compilation_mode.FASTBUILD,
            values = [
                _compilation_mode.FASTBUILD,
                _compilation_mode.DBG,
                _compilation_mode.OPT,
            ],
        ),
        use_legacy_manifest_merger = attr.bool(default = False),
        deps = attr.label_list(
            providers = [StarlarkAndroidResourcesInfo],
        ),
        _legacy_merger = ANDROID_BINARY_ATTRS.get("_android_manifest_merge_tool"),
        _xsltproc_tool = attr.label(
            cfg = "exec",
            default = Label("//tools/android/xslt:xslt"),
            allow_files = True,
        ),
        _add_g3itr_xslt = attr.label(
            cfg = "exec",
            default = Label("//tools/android/xslt:add_g3itr.xslt"),
            allow_single_file = True,
        ),
        _host_javabase = attr.label(
            cfg = "exec",
            default = Label("//tools/jdk:current_java_runtime"),
        ),
        _manifest_merge_order = attr.label(
            default = "//rules/flags:manifest_merge_order",
        ),
    ),
    toolchains = [
        "//toolchains/android:toolchain_type",
        "@bazel_tools//tools/jdk:toolchain_type",
        ANDROID_SDK_TOOLCHAIN_TYPE,
    ],
    fragments = [
        "android",
        "bazel_android",  # NOTE: Only exists for Bazel.
    ],
    provides = [_resources_testing.ResourcesPackageContextInfo],
)

def _resources_package_test_impl(ctx):
    dep = _utils.only(ctx.attr.deps)
    packaged_resources_ctx = dep[_resources_testing.ResourcesPackageContextInfo]
    manifest = packaged_resources_ctx.processed_manifest
    resource_apk = packaged_resources_ctx.resources_apk
    class_jar = packaged_resources_ctx.class_jar
    aapt = get_android_toolchain(ctx).aapt2.files_to_run.executable
    aapt_runfiles = get_android_toolchain(ctx).aapt2[DefaultInfo].default_runfiles.files

    test = ctx.actions.declare_file(ctx.label.name + "/test.sh")
    ctx.actions.write(
        test,
        """#!/bin/bash
set -eu

MANIFEST={manifest}
RESOURCE_APK={resource_apk}
CLASS_JAR={class_jar}
EXPECTED_IS_DEBUGGABLE={expected_is_debuggable}
EXPECTED_ASSETS={expected_assets}
EXPECTED_MANIFEST={expected_manifest}
EXPECTED_JAR_FILES={expected_jar_files}
EXPECTED_RES={expected_res}
AAPT={aapt}

diff_contents () {{
    set +e
    DIFF=`(diff --ignore-all-space "$1" "$2")`
    set -e
    if [[ "$DIFF" != "" ]]; then
        echo "Error: mismatch between expected and actual: $DIFF"
        exit 1
    fi
}}

# Only validate expected manifest provided.
if [[ "$EXPECTED_MANIFEST" != "" ]]; then
    diff_contents "$EXPECTED_MANIFEST" "$MANIFEST"
fi


JAR_FILES=`(unzip -l "$CLASS_JAR" | sed -e '1,3d' | head -n -2     | tr -s " " | cut -d" " -f5 | sort)`
EXPECTED_JAR_FILES=`(echo "$EXPECTED_JAR_FILES" | tr ',' '\n' | sort)`
diff_contents <( echo "$EXPECTED_JAR_FILES" ) <( echo "$JAR_FILES" )

# Validate debuggable in AndroidManifest.xml
#
# Debuggable is set in the compiled AndroidManifest.xml through an aapt2 flag.
# As such, validating debuggable can only be done by dumping the xmltree.
#
# Sample output, of "aapt2 dump xmltree --file AndroidManifest.xml":
#
# N: android=http://schemas.android.com/apk/res/android (line=1)
#  E: manifest (line=1)
#    A: http://schemas.android.com/apk/res/android:compileSdkVersion(0x01010572)=30
#    A: http://schemas.android.com/apk/res/android:compileSdkVersionCodename(0x01010573)="11" (Raw: "11")
#    A: package="com.google.compilation.mode.opt" (Raw: "com.google.compilation.mode.opt")
#    A: platformBuildVersionCode=30
#    A: platformBuildVersionName=11
#      E: uses-sdk (line=2)
#        A: http://schemas.android.com/apk/res/android:minSdkVersion(0x0101020c)=15
#        A: http://schemas.android.com/apk/res/android:targetSdkVersion(0x01010270)=29
#      E: application (line=3)
#        A: http://schemas.android.com/apk/res/android:debuggable(0x0101000f)=true'
#
# To mitigate the chances of a false positive, the test retrieves the uri of
# the "android" namespace which is prepended to debuggable and searches for
# the attribute and validates the value.
MANIFEST=$($AAPT dump xmltree $RESOURCE_APK --file AndroidManifest.xml)
ANDROID_NS=$(echo "$MANIFEST" | grep -e "^N: android=" |     sed -e "s/^N: android=\\(.\\+\\) .*$/\\1/")
DEBUGGABLE_ATTR="$ANDROID_NS:debuggable"
set +e  # Disable failure on non-0 return value, if debuggable entry is missing.
DEBUGGABLE_MANIFEST_ENTRY=$(echo "$MANIFEST" | grep "$DEBUGGABLE_ATTR")
set -e
DEBUGGABLE_VAL=$(echo "$DEBUGGABLE_MANIFEST_ENTRY" |     sed -e "s|^.*$DEBUGGABLE_ATTR(.*)=||")
set -x
if [ "$EXPECTED_IS_DEBUGGABLE" == true ] && [[ "$DEBUGGABLE_VAL" == "" ]]; then
    echo "Error, expected a debuggable apk, but did not get one."
    echo "No debuggable manifest entry found, see manifest:\n$MANIFEST"
    exit 1
elif [ "$EXPECTED_IS_DEBUGGABLE" == false ] && [[ "$DEBUGGABLE_VAL" == "true" ]]; then
    echo "Error, did not expected a debuggable apk, but get one."
    echo "The debuggable manifest entry found: $DEBUGGABLE_MANIFEST_ENTRY"
    exit 1
fi
set +x

# Validate resources
RES=$($AAPT dump resources -v $RESOURCE_APK | sed '/^\\s*resource/!d' \
    | tr -s ' ' '\t' | cut -f 4 | sort)
EXPECTED_RES=`(echo "$EXPECTED_RES" | tr ',' '\n' | sort)`
diff_contents <( echo "$EXPECTED_RES" ) <( echo "$RES" )

#Validate assets
ASSETS=$(unzip -l $RESOURCE_APK assets/* | tr -s ' ' '\t' | cut -f 5 \
    | tail -n +4 | head -n -2)
EXPECTED_ASSETS=`(echo "$EXPECTED_ASSETS" | tr ',' '\n' | sort)`
diff_contents <( echo "$EXPECTED_ASSETS" ) <( echo "$ASSETS" )
""".format(
            manifest = manifest.short_path,
            resource_apk = resource_apk.short_path,
            class_jar = class_jar.short_path,
            expected_assets = ",".join(ctx.attr.expected_assets),
            expected_jar_files = ",".join([
                "'%s'" % filename
                for filename in ctx.attr.expected_jar_files
            ]),
            expected_manifest =
                ctx.file.expected_manifest.short_path if ctx.attr.expected_manifest else "",
            expected_res = ",".join(ctx.attr.expected_res),
            expected_is_debuggable = (
                "true" if ctx.attr.expected_is_debuggable else "false"
            ),
            aapt = aapt.short_path,
        ),
        is_executable = True,
    )
    return DefaultInfo(
        executable = test,
        runfiles = ctx.runfiles(
            files = [
                manifest,
                resource_apk,
                class_jar,
                aapt,
            ] + (
                [ctx.file.expected_manifest] if ctx.attr.expected_manifest else []
            ),
            transitive_files = aapt_runfiles,
        ),
    )

resources_package_test = rule(
    implementation = _resources_package_test_impl,
    attrs = dict(
        deps = attr.label_list(
            providers = [_resources_testing.ResourcesPackageContextInfo],
        ),
        expected_assets = attr.string_list(),
        expect_databinding_enabled = attr.bool(default = False),
        # APKs are built debuggable, unless built with -c opt. As such the
        # default value is True.
        expected_is_debuggable = attr.bool(default = True),
        expected_jar_files = attr.string_list(),
        expected_manifest = attr.label(
            allow_single_file = True,
        ),
        expected_res = attr.string_list(),
    ),
    toolchains = ["//toolchains/android:toolchain_type"],
    test = True,
)

def _package_resources_final_id_test(ctx):
    env = analysistest.begin(ctx)
    target_under_test = analysistest.target_under_test(env)
    actions = analysistest.target_actions(env)
    found_final_r = False
    found_nonfinal_r = False
    for a in actions:
        if a.mnemonic == "StarlarkRClassGenerator":
            if "--finalFields" in a.argv:
                found_final_r = True
            elif "--nofinalFields" in a.argv:
                found_nonfinal_r = True

    if ctx.attr.final:
        # We expect to find both final and non-final if we're building a target
        # with final fields because we build both: nonfinal fields for `javac`
        # to build against and final fields for the deploy jar.
        asserts.true(env, found_final_r, "Missing expected --finalFields")
        asserts.true(env, found_nonfinal_r, "Missing expected --nofinalFields")
    else:
        asserts.false(env, found_final_r, "Unexpected --finalFields")
        asserts.true(env, found_nonfinal_r, "Missing expected --nofinalFields")

    return analysistest.end(env)

package_resources_final_id_test = analysistest.make(
    _package_resources_final_id_test,
    attrs = {
        "final": attr.bool(mandatory = True),
    },
)
