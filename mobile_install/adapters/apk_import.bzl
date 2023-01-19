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
"""Rule adapter for android_binary."""

load(":adapters/base.bzl", "make_adapter")
load(":providers.bzl", "MIAppInfo")
load(":utils.bzl", "utils")

def _aspect_attrs():
    """Attrs of the rule requiring traversal by the aspect."""
    return ["unsigned_apk"]

def adapt(target, ctx):
    # adapt is made visibile for testing
    """Adapts the android rule

    Args:
        target: The target.
        ctx: The context.
    Returns:
         A list of providers
    """
    apk = ctx.rule.file.unsigned_apk

    package_name_output_file = utils.isolated_declare_file(ctx, ctx.label.name + "/manifest_package_name.txt")

    utils.extract_package_name(ctx, apk, package_name_output_file)

    return [
        MIAppInfo(
            apk = apk,
            manifest_package_name = package_name_output_file,
        ),
    ]

apk_import = make_adapter(_aspect_attrs, adapt)
