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

"""Allow list for b/144163743, allowing implicit export of deps when resources and deps are present."""

ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS_GENERATOR_FUNCTIONS = []

ANDROID_LIBRARY_RESOURCES_WITHOUT_SRCS = ["//:__subpackages__"]
