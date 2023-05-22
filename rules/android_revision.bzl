# Copyright 2023 The Bazel Authors. All rights reserved.
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

"""Parse and compare Android revision strings."""

# TODO(katre): support preview versions.
AndroidRevisionInfo = provider(
    "Information about Android revision specifications.",
    fields = {
        "major": "The major version number",
        "minor": "The minor version number, or 0 if unset.",
        "micro": "The micro version number, or 0 if unset.",
        "version": "The version string.",
        "dir": "The directory where the revision would exist in an Android SDK.",
    },
)

def parse_android_revision(input):
    """Parse and Android revision string and return an AndroidRevisionInfo.

    Args:
      input: The raw revision string to parse.

    Returns:
      An AndroidRevisionInfo provider representing the input.
    """
    input = input.strip()
    parts = input.split(".")
    if len(parts) < 1:
        fail("Invalid Android revision %s" % input)
    major = int(parts[0]) if len(parts) >= 1 else 0
    minor = int(parts[1]) if len(parts) >= 2 else 0
    micro = int(parts[2]) if len(parts) >= 3 else 0

    return AndroidRevisionInfo(
        version = input,
        dir = input,
        major = major,
        minor = minor,
        micro = micro,
    )

def _compare_android_revision_field(first, second, name):
    first_val = getattr(first, name)
    second_val = getattr(second, name)
    if first_val > second_val:
        return first
    elif first_val < second_val:
        return second
    return None

def compare_android_revisions(first, second):
    """Compares two AndroidRevisionInfo providers and returns the one with the highest version.

    Args:
      first: The first revision to compare.
      second: The first revision to compare.

    Returns:
      The revision with the higher version number, or the first if they are equal.
    """
    if first == None and second == None:
        return None
    if first != None and second == None:
        return first
    if first == None and second != None:
        return second
    highest = _compare_android_revision_field(first, second, "major")
    if highest != None:
        return highest
    highest = _compare_android_revision_field(first, second, "minor")
    if highest != None:
        return highest
    highest = _compare_android_revision_field(first, second, "micro")
    if highest != None:
        return highest
    return first
