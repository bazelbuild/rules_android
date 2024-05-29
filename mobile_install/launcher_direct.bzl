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

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load("//rules/flags:flags.bzl", "flags")
load(":deploy_info.bzl", "make_deploy_info_pb")
load(":providers.bzl", "MIAppLaunchInfo")
load(":utils.bzl", "utils")

visibility(PROJECT_VISIBILITY)

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
        manifest_package_name_path,
        out_launcher,
        out_launcher_flags,
        splits = None,
        deploy_info_pb = None,
        test_apk = None,
        test_data = None,
        test_args = None,
        use_adb_root = True,
        use_studio_deployer = True,
        is_test = False):
    path_type = "path" if ctx.attr._mi_is_cmd else "short_path"

    deploy = utils.first(ctx.attr._deploy[DefaultInfo].files.to_list())

    args = {
        "is_cmd": str(ctx.attr._mi_is_cmd).lower(),
        "manifest_package_name_path": getattr(manifest_package_name_path, path_type),
        "target": ctx.label,
    }
    if splits:
        args["splits"] = [getattr(s, path_type) for s in splits]
        args["enable_splits"] = True

    if ctx.attr._mi_is_cmd:
        args["host_test_runner_workspace"] = HOST_TEST_WORKSPACE

    args["java_home"] = utils.host_jvm_path(ctx)

    args["studio_deployer"] = getattr(ctx.file._studio_deployer, path_type)
    args["use_adb_root"] = str(use_adb_root).lower()
    args["use_studio_deployer"] = str(use_studio_deployer).lower()

    args["use_direct_deploy"] = True

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
    return runner

def make_direct_launcher(
        ctx,
        mi_app_info,
        launcher,
        test_data = None,
        test_args = None,
        use_adb_root = True,
        is_test = False):
    """ Runfiles for launching the apps are created.

    Args:
        ctx: The context
        mi_app_info: The MIAppInfo provider
        launcher: The launcher file
        test_data: The test data
        test_args: The test arguments
        use_adb_root: Boolean argument to restart adb with root permissions.
        is_test: Boolean argument to identify if it's a test
    Returns:
        A list of files required for runtime common for both running binary and test.
    """
    runfiles = []

    launcher_flags = utils.isolated_declare_file(ctx, "launcher.flag", sibling = launcher)

    runfiles.extend([launcher, launcher_flags])

    runfiles.append(ctx.file._studio_deployer)
    if getattr(mi_app_info, "merged_manifest", None):
        runfiles.append(mi_app_info.merged_manifest)
    runfiles.append(mi_app_info.manifest_package_name)

    splits = None
    if hasattr(mi_app_info, "splits"):
        splits = mi_app_info.splits
        runfiles.extend(mi_app_info.splits)

    deploy_info_pb = None
    if hasattr(mi_app_info, "merged_manifest"):
        deploy_info_pb = make_deploy_info_pb(
            ctx,
            mi_app_info.merged_manifest,
            mi_app_info.splits,
        )
        runfiles.append(deploy_info_pb)

    if test_data:
        runfiles.extend(test_data)
    if is_test:
        test_apk = mi_app_info.apk
        runfiles.append(test_apk)
    else:
        test_apk = None

    runfiles.extend(_make_app_runner(
        ctx,
        mi_app_info.manifest_package_name,
        launcher,
        launcher_flags,
        splits = splits,
        deploy_info_pb = deploy_info_pb,
        test_apk = test_apk,
        test_data = test_data,
        test_args = test_args,
        use_adb_root = use_adb_root,
        use_studio_deployer = flags.get(ctx).use_studio_deployer,
        is_test = is_test,
    ))

    return MIAppLaunchInfo(
        launcher = launcher,
        launcher_flags = launcher_flags,
        runfiles = runfiles,
    )
