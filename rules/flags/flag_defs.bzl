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

"""Flag definitions."""

load("@rules_android//rules/flags:flags.bzl", "flags")

def define_flags():
    flags.DEFINE_bool(
        name = "android_enable_res_v3",
        default = False,
        description = "Enable Resource Processing Pipeline v3.",
    )

    flags.DEFINE_bool(
        name = "use_direct_deploy",
        default = False,
        description = "Enable direct deployment.",
    )

    flags.DEFINE_int(
        name = "num_dex_shards",
        default = 16,
        description = "Number of dex shards to use for mobile-install.",
    )

    flags.DEFINE_bool(
        name = "use_custom_dex_shards",
        default = False,
        description = "Whether to use custom dex shard value for mobile-install.",
    )

    flags.DEFINE_bool_group(
        name = "mi_v3",
        default = True,
        description = "Enable mobile-install v3.",
        flags = [
            # TODO(b/160897244): resv3 temporarily disabled while Starlark
            #     resource processing is implemented and rolled out
            # ":android_enable_res_v3",
            ":use_custom_dex_shards",
            ":use_direct_deploy",
        ],
    )

    flags.DEFINE_bool_group(
        name = "mi_dogfood",
        default = False,
        description = "Opt-in to mobile-install dogfood track.",
        flags = [
        ],
    )

    flags.DEFINE_bool(
        name = "enable_splits",
        default = False,
        description = "Build and install split apks if the device supports them.",
    )

    flags.DEFINE_bool(
        name = "use_adb_root",
        default = True,
        description = "Restart adb with root permissions.",
    )

    flags.DEFINE_bool(
        name = "mi_desugar_java8_libs",
        default = False,
        description = "Set True with --config=android_java8_libs",
    )

    flags.DEFINE_bool(
        name = "debug",
        default = False,
        description = "",
    )

    flags.EXPOSE_native_bool(
        name = "stamp",
        description = "Accesses the native --stamp CLI flag",
    )
