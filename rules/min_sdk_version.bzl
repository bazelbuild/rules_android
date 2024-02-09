# Copyright 2024 The Bazel Authors. All rights reserved.
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

""" Module for handling minSdkVersion configuration.

This module holds the current minimum minSdkVersion supported by the Android Rules. Additionally
it holds utilities for handling minSdkVersion propagation.

"""

_DEPOT_FLOOR = 19

min_sdk_version = struct(
    DEPOT_FLOOR = _DEPOT_FLOOR,
)
