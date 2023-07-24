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
"""Aspect for mobile-install."""

load(":adapters.bzl", "adapters")
load(":debug.bzl", "debug")
load(":tools.bzl", "TOOL_ATTRS")
load("//rules/flags:flags.bzl", "flags")

def aspect_impl(target, ctx):
    """Calls the adapter for a given rule and returns its providers.

    Args:
      target: Target of the MI command
      ctx: Current context

    Returns:
      A list of providers
    """
    adapter = adapters.get(ctx.rule.kind)

    if not adapter:
        return []

    # Debug.
    infos = adapter.adapt(target, ctx)
    if flags.get(ctx).debug:
        infos.append(OutputGroupInfo(**debug.make_output_groups(infos)))
    return infos

def make_aspect(
        dex_shards = 16,
        is_cmd = True,
        is_test = False,
        res_shards = 1,
        tools = TOOL_ATTRS):
    """Make aspect for incremental android apps.

    Args:
      dex_shards: Number of dex shards to split the project across.
      is_cmd: A Boolean, when True the aspect is running in the context of the
        mobile-install command. If False it is as a rule (e.g. mi_test).
      res_shards: Number of Android resource shards during processing.
    Returns:
      A configured aspect.
    """
    attrs = dict(
        _mi_dex_shards = attr.int(default = dex_shards),
        _mi_is_cmd = attr.bool(default = is_cmd),
        _mi_res_shards = attr.int(default = res_shards),
        _mi_is_test = attr.bool(default = is_test),
    )
    attrs.update(tools)
    return aspect(
        attr_aspects = adapters.get_all_aspect_attrs(),
        attrs = attrs,
        required_aspect_providers = [
            [JavaInfo],  # JavaLiteProtoLibrary aspect.
        ],
        fragments = ["cpp", "java"],
        host_fragments = ["jvm"],
        implementation = aspect_impl,
    )

# MIASPECT allows you to run the aspect directly on a Blaze/Bazel command.
#
# Example:
#   bazel build \
#     --aspects=@rules_android//mobile_install:mi.bzl%MIASPECT
#     --output_groups=mobile_install_INTERNAL_,mobile_install_launcher_INTERNAL_,-_,-defaults \
#     java/com/example/exampleapp:exampleapp
MIASPECT = make_aspect()
MIRESASPECT = MIASPECT  # Deprecated, needs to get removed from MobileInstallCommand.java first.
