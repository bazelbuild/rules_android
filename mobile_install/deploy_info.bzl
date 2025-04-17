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
"""Functions to create the deploy info proto used by ASwB."""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")
load(":utils.bzl", "utils")

visibility(PROJECT_VISIBILITY)

def make_deploy_info_pb(ctx, manifest, apks):
    """Builds a android_deploy_info pb for ASwB.

    proto def in src/tools/deploy_info/proto/android_deploy_info.proto

    Args:
      ctx: The context.
      manifest: the merged manifest of the application
      apks: the mobile_install apks

    Returns:
      The android_deploy_info pb
    """

    # _mi.deployinfo.pb suffix is used by Android Studio to select our deploy info.
    # Do not change this suffix without coordinating with an Android Studio change.
    deploy_info_pb = utils.isolated_declare_file(ctx, ctx.label.name + "_mi.deployinfo.pb")

    args = ctx.actions.args()
    args.add("--manifest", manifest)
    args.add_joined("--apk", apks, join_with = ",")
    args.add("--deploy_info", deploy_info_pb)

    ctx.actions.run(
        executable = ctx.executable._deploy_info,
        arguments = [args],
        outputs = [deploy_info_pb],
        mnemonic = "DeployInfo",
        progress_message = "MI DeployInfo",
    )

    return deploy_info_pb
