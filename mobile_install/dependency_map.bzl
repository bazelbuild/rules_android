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
    android_kit = struct(
        head = "//src/tools/ak",
    ),
    desugar_dex_sharding = struct(
        head = "//src/tools/java/com/google/devtools/build/android:DesugarDexShardingAction_deploy.jar",
    ),
    bootstraper = struct(
        head = "//tools/android:gen_fail",
    ),
    deploy = struct(
        head = "//src/tools/mi/deployment_oss:deploy_binary",
    ),
    deploy_info = struct(
        head = "//src/tools/deploy_info:deploy_info",
    ),
    forwarder = struct(
        head = "//tools/android:gen_fail",
    ),
    jar_tool = struct(
        head = "@bazel_tools//tools/jdk:JavaBuilder_deploy.jar",
    ),
    res_v3_dummy_manifest = struct(
        head = "//rules:res_v3_dummy_AndroidManifest.xml",
    ),
    res_v3_dummy_r_txt = struct(
        head = "//rules:res_v3_dummy_R.txt",
    ),
    resource_extractor = struct(
        head = "//tools/android:gen_fail",
    ),
)
