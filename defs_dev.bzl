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

"""Workspace setup macro for rules_android development."""

load("@cgrindel_bazel_starlib//:deps.bzl", "bazel_starlib_dependencies")
load("@rules_bazel_integration_test//bazel_integration_test:defs.bzl", "bazel_binaries")
load(":defs.bzl", non_dev_workspace = "rules_android_workspace")

def rules_android_workspace():
    non_dev_workspace()

    # Integration test setup
    bazel_starlib_dependencies()

    bazel_binaries(
        versions = [
            "last_green",
        ],
    )
