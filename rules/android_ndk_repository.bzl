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

"""Bazel rule for Android ndk repository."""

def android_ndk_repository(**attrs):
    """Bazel android_ndk_repository rule.

    https://docs.bazel.build/versions/master/be/android.html#android_ndk_repository

    Args:
      **attrs: Rule attributes
    """
    native.android_ndk_repository(**attrs)
