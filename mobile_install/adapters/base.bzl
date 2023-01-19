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
"""Provides the base adapter functions."""

def make_adapter(aspect_attrs, adapt):
    """Creates an Adapter.

    Args:
      aspect_attrs: A function that returns a list of attrs for the aspect.
      adapt: A function that extracts and processes data from the target.

    Returns:
      A struct that represents an adapter.
    """
    if not aspect_attrs:
        fail("aspect_attrs is None.")
    if not adapt:
        fail("adapt is None.")
    return struct(
        aspect_attrs = aspect_attrs,
        adapt = adapt,
    )
