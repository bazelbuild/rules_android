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

"""Bazel rule for the device script fixture."""

def android_device_script_fixture(**attrs):
    """Bazel android_device_script_fixture rule.

    https://docs.bazel.build/versions/master/be/android.html#android_device_script_fixture

    Args:
      **attrs: Rule attributes
    """
    native.android_device_script_fixture(**attrs)
