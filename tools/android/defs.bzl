# Copyright 2020 The Bazel Authors. All rights reserved.
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

"""A rule that returns android.jar from the current android sdk."""

def _android_jar_impl(ctx):
    return DefaultInfo(
        files = depset([ctx.attr._sdk[AndroidSdkInfo].android_jar]),
    )

android_jar = rule(
    implementation = _android_jar_impl,
    attrs = {
        "_sdk": attr.label(default = "@androidsdk//:sdk"),
    },
)
