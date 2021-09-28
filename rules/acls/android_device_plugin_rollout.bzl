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

"""Allow and fallback lists for ATP Device Plugin rollout."""

# Targets for ATP Device Plugin Rollout
ANDROID_DEVICE_PLUGIN_ROLLOUT = [
    "//:__subpackages__",
]

_READY_TO_ROLLOUT_IN_NEXT_RELEASE = [
]

ANDROID_DEVICE_PLUGIN_FALLBACK = [
] + _READY_TO_ROLLOUT_IN_NEXT_RELEASE
