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

"""Defines the emulator_toolchain rule to allow configuring emulator binaries to use."""

EmulatorInfo = provider(
    doc = "Information used to launch a specific version of the emulator.",
    fields = {
        "emulator": "A label for the emulator launcher executable at stable version.",
        "emulator_deps": "Additional files required to launch the stable version of emulator.",
        "emulator_head": "A label for the emulator launcher executable at head version.",
        "emulator_head_deps": "Additional files required to launch the head version of emulator.",
    },
)

def _emulator_toolchain_impl(ctx):
    toolchain_info = platform_common.ToolchainInfo(
        info = EmulatorInfo(
            emulator = ctx.attr.emulator,
            emulator_deps = ctx.attr.emulator_deps,
            emulator_head = ctx.attr.emulator_head,
            emulator_head_deps = ctx.attr.emulator_head_deps,
        ),
    )
    return [toolchain_info]

emulator_toolchain = rule(
    implementation = _emulator_toolchain_impl,
    attrs = {
        "emulator": attr.label(
            allow_files = True,
            cfg = "host",
            executable = True,
            mandatory = True,
        ),
        "emulator_deps": attr.label_list(
            allow_files = True,
            cfg = "host",
        ),
        "emulator_head": attr.label(
            allow_files = True,
            cfg = "host",
            executable = True,
        ),
        "emulator_head_deps": attr.label_list(
            allow_files = True,
            cfg = "host",
        ),
    },
)
