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

load(":utils.bzl", "utils")
load(":workspace.bzl", "make_dex_sync", "make_generic_sync", "merge_syncs")
load(":deploy_info.bzl", "make_deploy_info_pb")
load(":providers.bzl", "MIAppInfo", "MIAppLaunchInfo")
load("//rules/flags:flags.bzl", "flags")

HOST_TEST_WORKSPACE = "host_test_runner_workspace"

_DEPLOY_SCRIPT = '''#!/bin/bash
set -e  # exit on failure
umask 022  # set default file/dir creation mode to 755

FLAGS={flags}
TEST_FLAGS={test_flags}
DEPLOY={deploy}


ALL_TEST_ARGS=("$@")
if [[ ! -z ${{TEST_FLAGS}} ]];
then
  RULE_TEST_ARGS={test_args}
  ALL_TEST_ARGS=("--nolaunch_app" "${{RULE_TEST_ARGS[@]}}" "$@")
  "${{DEPLOY}}" \
      -flagfile="${{TEST_FLAGS}}"  \
      "${{ALL_TEST_ARGS[@]}}"
else
    "${{DEPLOY}}" -flagfile="${{FLAGS}}" \
      "${{ALL_TEST_ARGS[@]}}"
fi

'''

def _make_deploy_script(
        ctx,
        out_script,
        deploy,
        flags,
        test_args = "",
        test_flags = ""):
    deploy_contents = _DEPLOY_SCRIPT.format(
        deploy = deploy,
        flags = flags,
        test_flags = test_flags,
        test_args = test_args,
    )
    ctx.actions.write(out_script, deploy_contents, is_executable = True)

def _make_app_runner(
        ctx,
        sync,
        manifest_package_name_path,
        out_launcher,
        out_launcher_flags,
        shell_apk = None,
        splits = None,
        deploy_info_pb = None,
        test_apk = None,
        test_data = None,
        test_args = None,
        instrumented_app_package_name = None,
        use_adb_root = True,
        enable_metrics_logging = False,
        use_studio_deployer = True,
        is_test = False):
    path_type = "path" if ctx.attr._mi_is_cmd else "short_path"

    deploy = utils.first(ctx.attr._deploy.files.to_list())

    args = {
        "data_sync_path": getattr(sync, path_type),
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

    args["java_home"] = utils.host_jvm_path(ctx)

    args["studio_deployer"] = getattr(ctx.file._studio_deployer, path_type)
    args["use_adb_root"] = str(use_adb_root).lower()
    args["enable_metrics_logging"] = str(enable_metrics_logging).lower()
    args["use_studio_deployer"] = str(use_studio_deployer).lower()

    args["use_direct_deploy"] = True

    android_test_runner = None
    if is_test and hasattr(ctx.attr, "_android_test_runner"):
        android_test_runner = ctx.file._android_test_runner
        args["android_test_runner"] = getattr(android_test_runner, path_type)
        args["is_test"] = True

    if test_data:
        args["data_files"] = ",".join([f.short_path for f in test_data])

    if test_apk:
        args["test_apk"] = test_apk.path

    if instrumented_app_package_name:
        args["instrumented_app_package_name"] = getattr(instrumented_app_package_name, path_type)

    if deploy_info_pb:
        args["deploy_info"] = getattr(deploy_info_pb, path_type)

    utils.create_flag_file(ctx, out_launcher_flags, **args)

    _make_deploy_script(
        ctx,
        out_launcher,
        getattr(deploy, path_type),
        flags = getattr(out_launcher_flags, path_type),
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

def make_direct_launcher(
        ctx,
        mi_app_info,
        launcher,
        test_data = None,
        test_args = None,
        test_support_apps = None,
        use_adb_root = True,
        is_test = False):
    """ Runfiles for launching the apps are created.

    Args:
        ctx: The context
        mi_app_info: The MIAppInfo provider
        launcher: The launcher file
        test_data: The test data
        test_support_apps: The test support apps
        test_args: The test arguments
        use_adb_root: Boolean argument to restart adb with root permissions.
        is_test: Boolean argument to identify if it's a test
    Returns:
        A list of files required for runtime common for both running binary and test.
    """
    app_pbs = []
    runfiles = []

    launcher_flags = utils.isolated_declare_file(ctx, "launcher.flag", sibling = launcher)

    runfiles.extend([launcher, launcher_flags])

    runfiles.append(ctx.file._studio_deployer)
    if getattr(mi_app_info, "merged_manifest", None):
        runfiles.append(mi_app_info.merged_manifest)
    runfiles.append(mi_app_info.manifest_package_name)

    shell_apk = None
    if hasattr(mi_app_info, "shell_apk") and mi_app_info.shell_apk:
        shell_apk = mi_app_info.shell_apk
        app_pbs.append(
            make_generic_sync(
                ctx,
                files = [shell_apk],
                replacements = [
                    shell_apk.short_path[:shell_apk.short_path.rindex("/")],
                    "apk",
                ],
                sibling = launcher,
            ),
        )
        runfiles.append(mi_app_info.shell_apk)

    splits = None
    if hasattr(mi_app_info, "splits"):
        splits = mi_app_info.splits
        runfiles.extend(mi_app_info.splits)

    if hasattr(mi_app_info, "native_zip") and mi_app_info.native_zip:
        app_pbs.append(make_generic_sync(ctx, zips = [mi_app_info.native_zip], sibling = launcher))
        runfiles.append(mi_app_info.native_zip)

    if hasattr(mi_app_info, "r_dex"):
        runfiles.append(mi_app_info.r_dex)
        app_pbs.append(make_dex_sync(ctx, mi_app_info.r_dex, dir_name = "rdexes", sibling = launcher))

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
        app_pbs.append(bin_dex_sync)

    deploy_info_pb = None
    if hasattr(mi_app_info, "merged_manifest"):
        deploy_info_pb = make_deploy_info_pb(
            ctx,
            mi_app_info.merged_manifest,
            mi_app_info.splits if mi_app_info.splits else [mi_app_info.shell_apk],
        )
        runfiles.append(deploy_info_pb)

    if test_data:
        runfiles.extend(test_data)
    if is_test:
        test_apk = mi_app_info.apk
        runfiles.append(test_apk)
    else:
        test_apk = None

    sync = utils.make_sync(ctx, app_pbs, mi_app_info.manifest_package_name, "app", sibling = launcher)
    runfiles.append(sync)

    sync_pbs = []
    sync_pbs.append(sync)
    instrumented_app_package_name = None
    instrumented_app = None
    if hasattr(mi_app_info, "instrumented_app") and mi_app_info.instrumented_app:
        sync_pbs.append(mi_app_info.instrumented_app[MIAppLaunchInfo].sync)
        runfiles.extend(mi_app_info.instrumented_app[MIAppLaunchInfo].runfiles)
        instrumented_app_package_name = mi_app_info.instrumented_app[MIAppInfo].manifest_package_name

    if test_support_apps:
        for support_app in test_support_apps:
            if MIAppLaunchInfo in support_app:
                sync_pbs.append(support_app[MIAppLaunchInfo].sync)
                runfiles.extend(support_app[MIAppLaunchInfo].runfiles)

    if len(sync_pbs) > 1:
        final_sync_pb = utils.sync_merger(ctx, sync_pbs, sibling = launcher)
        runfiles.append(final_sync_pb)
    else:
        final_sync_pb = sync

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
        test_data = test_data,
        test_args = test_args,
        instrumented_app_package_name = instrumented_app_package_name,
        use_adb_root = use_adb_root,
        enable_metrics_logging = flags.get(ctx).enable_metrics_logging,
        use_studio_deployer = flags.get(ctx).use_studio_deployer,
        is_test = is_test,
    ))

    return MIAppLaunchInfo(
        launcher = launcher,
        launcher_flags = launcher_flags,
        runfiles = runfiles,
        sync = sync,
    )
