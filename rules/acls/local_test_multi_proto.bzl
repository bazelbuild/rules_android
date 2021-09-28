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

"""Allowlist for android_local_test targets allowed to depend on java_proto_library.

See b/120162253 for context.
"""

LOCAL_TEST_MULTI_PROTO = [
]

LOCAL_TEST_MULTI_PROTO_PKG = [x + ":__pkg__" for x in LOCAL_TEST_MULTI_PROTO]
