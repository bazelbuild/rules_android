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

"""A repository rule for integrating the Android SDK."""

def _parse_version(version):
    # e.g.:
    # "33.1.1" -> 330101
    #  "4.0.0" ->  40000
    # "33.1.1" < "4.0.0" but 330101 > 40000
    major, minor, micro = version.split(".")
    return (int(major) * 10000 + int(minor) * 100 + int(micro), version)

def _android_sdk_supplemental_repository_impl(ctx):
    """A repository for additional SDK content.

    Needed until android_sdk_repository is fully in Starlark.

    Args:
        ctx: An implementation context.

    Returns:
        A final dict of configuration attributes and values.
    """
    sdk_path = ctx.attr.path or ctx.os.environ.get("ANDROID_HOME", None)
    if not sdk_path:
        fail("Either the ANDROID_HOME environment variable or the " +
             "path attribute of android_sdk_supplemental_repository " +
             "must be set.")

    build_tools_dirs = ctx.path(sdk_path + "/build-tools").readdir()
    _, highest_build_tool_version = (
        max([_parse_version(v.basename) for v in build_tools_dirs])
    )
    ctx.symlink(
        sdk_path + "/build-tools/" + highest_build_tool_version,
        "build-tools/" + highest_build_tool_version,
    )
    ctx.file(
        "BUILD",
        """
filegroup(
  name  = "dexdump",
  srcs = ["build-tools/%s/dexdump"],
  visibility = ["//visibility:public"],
)
""" % highest_build_tool_version,
    )

android_sdk_supplemental_repository = repository_rule(
    attrs = {
        "path": attr.string(),
    },
    local = True,
    implementation = _android_sdk_supplemental_repository_impl,
)
