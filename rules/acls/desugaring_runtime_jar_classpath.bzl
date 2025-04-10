# Copyright 2025 The Bazel Authors. All rights reserved.
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
"""ACL for switching between compile time JARs to runtime JARs in the Desugaring classpath."""

load("//rules:visibility.bzl", "PROJECT_VISIBILITY")

visibility(PROJECT_VISIBILITY)

# This is a boolean because it changes the behavior of two difference aspects. One is applied via
# rule attributes. The other is applied via the command line. There is clean way to get the
# top-level target the aspect is applied to in these cases. In the end we just want to be able to
# turn this feature entirely on or off independently of a release.
DESUGAR_USE_RUNTIME_JARS = False
