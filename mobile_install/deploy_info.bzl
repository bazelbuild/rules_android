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
"""Functions to create the deploy info proto used by ASwB."""

load(":utils.bzl", "utils")

def make_deploy_info_pb(ctx, _unused_manifest, _unused_apks):
    """Builds a android_deploy_info pb for ASwB.

    proto def in bazel/src/main/protobuf/android_deploy_info.proto.
    For now, just writes an empty file to the pb.

    Args:
      ctx: The context.
      _unused_manifest: the merged manifest of the application
      _unused_apks: the mobile_install apks

    Returns:
      The android_deploy_info pb
    """

    # _mi.deployinfo.pb suffix is used by Android Studio to select our deploy info.
    # Do not change this suffix without coordinating with an Android Studio change.
    deploy_info_pb = utils.isolated_declare_file(ctx, ctx.label.name + "_mi.deployinfo.pb")

    ctx.actions.run_shell(
        outputs = [deploy_info_pb],
        command = "echo > " + deploy_info_pb.path,
    )

    return deploy_info_pb
