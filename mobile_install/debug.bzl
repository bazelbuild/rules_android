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
"""Module that enables debugging for mobile-install."""

def _make_output_groups(infos):
    output_groups = dict()
    for info in infos:
        if hasattr(info, "info"):
            output_group = dict(
                mi_java_info = info.info.runtime_output_jars,
            )
        elif hasattr(info, "transitive_java_resources"):
            output_group = dict(
                mi_java_resources_info = info.transitive_java_resources,
            )
        elif hasattr(info, "transitive_native_libs"):
            output_group = dict(
                mi_aar_native_libs_info = info.transitive_native_libs,
            )
        elif hasattr(info, "transitive_dex_shards"):
            output_group = dict(
                mi_android_dex_info = depset(
                    transitive = info.transitive_dex_shards,
                ),
            )
        else:
            fail("Unsupported provider %s" % info)
        output_groups.update(output_group)
    return output_groups

debug = struct(
    make_output_groups = _make_output_groups,
)
