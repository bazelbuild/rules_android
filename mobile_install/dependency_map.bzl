# Copyright 2022 The Bazel Authors. All rights reserved.
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

"""This file keeps track of the locations of binaries for Mobile-Install."""

versioned_deps = struct(
    mi_shell_app = struct(
        head = "//tools/android:fail",
    ),
    android_kit = struct(
        head = "//src/tools/ak",
    ),
    bootstraper = struct(
        head = "//tools/android:fail",
    ),
    deploy = struct(
        head = "//src/tools/mi/deployment:deploy_binary",
    ),
    deploy_info = struct(
        head = "//src/tools/mi/deploy_info:deploy_info",
    ),
    forwarder = struct(
        head = "//tools/android:fail",
    ),
    jar_tool = struct(
        head = "@bazel_tools//tools/jdk:JavaBuilder_deploy.jar",
    ),
    make_sync = struct(
        head = "//src/tools/mi/app_info:make_sync",
    ),
    merge_syncs = struct(
        head = "//src/tools/mi/workspace:merge_syncs",
    ),
    pack_dexes = struct(
        head = "//src/tools/mi/workspace:pack_dexes",
    ),
    pack_generic = struct(
        head = "//src/tools/mi/workspace:pack_generic",
    ),
    res_v3_dummy_manifest = struct(
        head = "//rules:res_v3_dummy_AndroidManifest.xml",
    ),
    res_v3_dummy_r_txt = struct(
        head = "//rules:res_v3_dummy_R.txt",
    ),
    resource_extractor = struct(
        head = "//src/tools/resource_extractor:main",
    ),
    sync_merger = struct(
        head = "//src/tools/mi/app_info:sync_merger",
    ),
)
