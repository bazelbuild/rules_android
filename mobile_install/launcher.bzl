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
"""Creates the app launcher scripts."""

load(":deploy_info.bzl", "make_deploy_info_pb")
load(":providers.bzl", "MIAppInfo", "MIAppLaunchInfo")
load(":utils.bzl", "utils")
load(":workspace.bzl", "make_dex_sync", "make_generic_sync", "merge_syncs")
load("//rules/flags:flags.bzl", "flags")

HOST_TEST_WORKSPACE = "host_test_runner_workspace"

_DEPLOY_SCRIPT = '''#!/bin/bash
set -e  # exit on failure
umask 022  # set default file/dir creation mode to 755

APP_FLAGS={app_flags}
GOOGPLAYSRVCS_CONTAINER_FLAGS={googplayservices_container_flags}
TEST_FLAGS={test_flags}
DEPLOY={deploy}

ALL_TEST_ARGS=("$@")
if [[ ! -z ${{TEST_FLAGS}} ]]; then
  RULE_TEST_ARGS={test_args}
  ALL_TEST_ARGS=("--nolaunch_app" "${{RULE_TEST_ARGS[@]}}" "$@")
fi

if [[ ! -z ${{GOOGPLAYSRVCS_CONTAINER_FLAGS}} ]]; then
  "${{DEPLOY}}" \
      -flagfile="${{GOOGPLAYSRVCS_CONTAINER_FLAGS}}" \
        "${{ALL_TEST_ARGS[@]}}"
fi

if [[ ! -z ${{APP_FLAGS}} ]]; then
  "${{DEPLOY}}" \
      -flagfile="${{APP_FLAGS}}" \
      "${{ALL_TEST_ARGS[@]}}"
fi

if [[ ! -z ${{TEST_FLAGS}} ]]; then
  "${{DEPLOY}}" \
      -flagfile="${{TEST_FLAGS}}" \
      --is_test=true \
      "${{ALL_TEST_ARGS[@]}}"
fi
'''

def _make_deploy_script(
        ctx,
        out_script,
        deploy,
        app_flags = "",
        googplayservices_container_flags = "",
        test_flags = "",
        test_args = ""):
    deploy_contents = _DEPLOY_SCRIPT.format(
        app_flags = app_flags,
        googplayservices_container_flags = googplayservices_container_flags,
        deploy = deploy,
        test_flags = test_flags,
        test_args = test_args,
    )
    ctx.actions.write(out_script, deploy_contents, is_executable = True)

def _make_app_runner(
        ctx,
        data_sync,
        manifest_package_name_path,
        out_launcher,
        out_launcher_flags,
        shell_apk = None,
        splits = None,
        deploy_info_pb = None,
        test_apk = None,
        test_support_apks = None,
        test_data = None,
        test_args = None,
        instrumented_app = None,
        googplayservices_container_app = None,
        use_adb_root = True,
        enable_metrics_logging = False,
        is_test = False):
    path_type = "path" if ctx.attr._mi_is_cmd else "short_path"

    deploy = utils.first(ctx.attr._deploy.files.to_list())

    args = {
        "data_sync_path": getattr(data_sync, path_type),
        "is_cmd": str(ctx.attr._mi_is_cmd).lower(),
        "manifest_package_name_path": getattr(manifest_package_name_path, path_type),
        "target": ctx.label,
    }
    if shell_apk:
        args["shell_app_path"] = getattr(shell_apk, path_type)

    if splits:
        args["splits"] = [getattr(s, path_type) for s in splits]
        args["enable_splits"] = True

    if ctx.attr._mi_is_cmd:
        args["host_test_runner_workspace"] = HOST_TEST_WORKSPACE
    if test_support_apks or test_apk:
        args["apks"] = ",".join([apk.short_path for apk in [test_apk] + test_support_apks])

    args["java_home"] = utils.host_jvm_path(ctx)

    args["studio_deployer"] = getattr(ctx.file._studio_deployer, path_type)
    args["use_adb_root"] = str(use_adb_root).lower()
    args["enable_metrics_logging"] = str(enable_metrics_logging).lower()

    android_test_runner = None
    if is_test and hasattr(ctx.attr, "_android_test_runner"):
        android_test_runner = ctx.file._android_test_runner
        args["android_test_runner"] = getattr(android_test_runner, path_type)

    if test_data:
        args["data_files"] = ",".join([f.short_path for f in test_data])

    if test_apk:
        args["test_apk"] = test_apk.path

    if deploy_info_pb:
        args["deploy_info"] = getattr(deploy_info_pb, path_type)

    utils.create_flag_file(ctx, out_launcher_flags, **args)

    _make_deploy_script(
        ctx,
        out_launcher,
        getattr(deploy, path_type),
        app_flags = (
            getattr(instrumented_app[MIAppLaunchInfo].launcher_flags, path_type) if instrumented_app else getattr(out_launcher_flags, path_type)
        ),
        googplayservices_container_flags = (
            getattr(googplayservices_container_app[MIAppLaunchInfo].launcher_flags, path_type) if googplayservices_container_app else ""
        ),
        # Converts the python array of args into a bash array. Each arg is
        # wrapped with quotes to handle "space" separted flag value entries
        # and as result also escapes existing quotes.
        test_args = ("(%s)" % " ".join([
            '"--test_arg=%s"' % arg.replace('"', '\\"')
            for arg in test_args
        ])) if test_args else "",
        test_flags = getattr(out_launcher_flags, path_type) if test_args or is_test else "",
    )

    runner = [deploy]
    if android_test_runner:
        runner.extend(ctx.attr._java_jdk.files.to_list())
        runner.append(android_test_runner)
    return runner

def make_launcher(
        ctx,
        mi_app_info,
        launcher,
        test_data = None,
        test_args = None,
        test_support_apks = None,
        googplayservices_container_app = None,
        use_adb_root = True,
        is_test = False):
    """ Runfiles for launching the apps are created.

    Args:
        ctx: The context
        mi_app_info: The MIAppInfo provider
        launcher: The launcher file
        test_data: The test data
        test_support_apks: The test support apks
        test_args: The test arguments
        googplayservices_container_app: The Google Play Services container app
        use_adb_root: Boolean argument to restart adb with root permissions.
        is_test: Boolean argument to identify if it's a test
    Returns:
        A list of files required for runtime common for both running binary and test.
    """
    sync_pbs = []
    runfiles = []

    launcher_flags = utils.isolated_declare_file(ctx, "launcher.flag", sibling = launcher)

    runfiles.extend([launcher, launcher_flags])

    runfiles.append(ctx.file._studio_deployer)
    if getattr(mi_app_info, "merged_manifest", None):
        runfiles.append(mi_app_info.merged_manifest)
    runfiles.append(mi_app_info.manifest_package_name)
    shell_apk = None
    splits = None
    if not is_test:
        if hasattr(mi_app_info, "shell_apk"):
            shell_apk = mi_app_info.shell_apk
            runfiles.append(mi_app_info.shell_apk)

        if hasattr(mi_app_info, "splits"):
            splits = mi_app_info.splits
            runfiles.extend(mi_app_info.splits)

        if hasattr(mi_app_info, "native_zip") and mi_app_info.native_zip:
            sync_pbs.append(make_generic_sync(ctx, zips = [mi_app_info.native_zip], sibling = launcher))
            runfiles.append(mi_app_info.native_zip)

        if hasattr(mi_app_info, "r_dex"):
            runfiles.append(mi_app_info.r_dex)
            sync_pbs.append(make_dex_sync(ctx, mi_app_info.r_dex, dir_name = "rdexes", sibling = launcher))

    if hasattr(mi_app_info, "merged_dex_shards"):
        runfiles.extend(mi_app_info.merged_dex_shards)
        bin_dex_sync = merge_syncs(
            ctx,
            [
                make_dex_sync(ctx, dex_shard, sibling = launcher)
                for dex_shard in mi_app_info.merged_dex_shards
            ],
            "bin",
            sibling = launcher,
        )
        sync_pbs.append(bin_dex_sync)

    instrumented_app = None
    if hasattr(mi_app_info, "instrumented_app") and mi_app_info.instrumented_app:
        instrumented_app = mi_app_info.instrumented_app
        runfiles.extend(mi_app_info.instrumented_app[MIAppInfo].merged_dex_shards)

        # Add the binary under test dex shards to find additional tests.
        but_dex_sync = merge_syncs(
            ctx,
            [
                make_dex_sync(ctx, dex_shard, sibling = launcher)
                for dex_shard in mi_app_info.instrumented_app[MIAppInfo].merged_dex_shards
            ],
            "but",
            sibling = launcher,
        )
        sync_pbs.append(but_dex_sync)

    if test_data:
        runfiles.extend(test_data)
    if test_support_apks:
        runfiles.extend(test_support_apks)
    if is_test:
        test_apk = mi_app_info.apk
        runfiles.append(test_apk)
    else:
        test_apk = None

    if hasattr(mi_app_info, "shell_apk") and mi_app_info.shell_apk and not is_test:
        sync_pbs.append(
            make_generic_sync(
                ctx,
                files = [mi_app_info.shell_apk],
                replacements = [
                    mi_app_info.shell_apk.short_path[:mi_app_info.shell_apk.short_path.rindex("/")],
                    "apk",
                ],
                sibling = launcher,
            ),
        )
    deploy_info_pb = None
    if hasattr(mi_app_info, "merged_manifest"):
        deploy_info_pb = make_deploy_info_pb(
            ctx,
            mi_app_info.merged_manifest,
            mi_app_info.splits if mi_app_info.splits else [mi_app_info.shell_apk],
        )
        runfiles.append(deploy_info_pb)

    final_sync_pb = None

    # Create the final sync pb.
    if ctx.var.get("use_direct_deploy"):
        final_sync_pb = utils.make_sync(ctx, sync_pbs, mi_app_info.manifest_package_name, "app", sibling = launcher)
    else:
        final_sync_pb = merge_syncs(ctx, sync_pbs, "app", sibling = launcher)
    runfiles.append(final_sync_pb)

    runfiles.extend(_make_app_runner(
        ctx,
        final_sync_pb,
        mi_app_info.manifest_package_name,
        launcher,
        launcher_flags,
        shell_apk = shell_apk,
        splits = splits,
        deploy_info_pb = deploy_info_pb,
        test_apk = test_apk,
        test_support_apks = test_support_apks,
        test_data = test_data,
        test_args = test_args,
        instrumented_app = instrumented_app,
        googplayservices_container_app = googplayservices_container_app,
        use_adb_root = use_adb_root,
        enable_metrics_logging = flags.get(ctx).enable_metrics_logging,
        is_test = is_test,
    ))

    # Collect launcher details for additional apps
    mi_app_launch_infos = []
    if instrumented_app:
        mi_app_launch_infos.append(mi_app_info.instrumented_app[MIAppLaunchInfo])
    if googplayservices_container_app:
        mi_app_launch_infos.append(googplayservices_container_app[MIAppLaunchInfo])

    # Append the additional launch and launcher flags.
    if mi_app_launch_infos:
        for mi_app_launch_info in mi_app_launch_infos:
            runfiles.append(mi_app_launch_info.launcher_flags)
            runfiles.extend(mi_app_launch_info.runfiles)

    return MIAppLaunchInfo(
        launcher = launcher,
        launcher_flags = launcher_flags,
        runfiles = runfiles,
    )
