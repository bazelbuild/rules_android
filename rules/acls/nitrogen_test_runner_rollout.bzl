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

"""Allow and fallback lists for Nitrogen rollout"""

# Nitrogen targets for android_instrumentation_test rollout
NITROGEN_TEST_RUNNER_ROLLOUT = [
    "//:__subpackages__",
]

# Nitrogen targets for android_test rollout
NITROGEN_AT_TEST_RUNNER_ROLLOUT = [
    "//:__subpackages__",
]

NITROGEN_TEST_RUNNER_FALLBACK = [
]
