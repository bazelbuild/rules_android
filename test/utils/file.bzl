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

"""Bazel lib that provides on-the-fly data generation helpers for testing."""

def _create(
        name = None,
        contents = "",
        executable = False):
    target_name = "gen_" + name.replace(".", "_")
    native.genrule(
        name = target_name,
        cmd = """
cat > $@ <<MAKE_FILE_EOM
%s
MAKE_FILE_EOM
""" % contents,
        outs = [name],
        executable = executable,
    )
    return name

def _create_mock_file(path, is_directory = False):
    return struct(
        path = path,
        dirname = path.rpartition("/")[0],
        is_directory = is_directory,
    )

file = struct(
    create = _create,
    create_mock_file = _create_mock_file,
)
