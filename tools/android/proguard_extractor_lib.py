# pylint: disable=g-direct-third-party-import
# Copyright 2026 The Bazel Authors. All rights reserved.
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
"""Shared library for extracting proguard spec files from JARs and AARs."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import io
import re
import zipfile


def _parse_version(ver:str):
  return tuple(int(x) for x in ver.split("."))


def _ExtractTargetedR8Rules(jar, output, r8_version):
  """Extract version-targeted R8 rules from META-INF/com.android.tools/.

  Returns True if any matching rules were found and written.
  """
  if not r8_version:
    return

  r8_prefix = "META-INF/com.android.tools/"

  targeted_entries = []
  for entry in sorted(jar.namelist()):
    if entry.startswith(r8_prefix) and re.match("r8-from-[^/]+-upto-[^/]+", entry[len(r8_prefix):]):
      match = re.search("r8-from-([^/]+)-upto-([^/]+)", entry)
      if match:
        lower_bound, upper_bound = match.groups()
        if _parse_version(lower_bound) <= _parse_version(r8_version) < _parse_version(upper_bound):
          targeted_entries.append(entry)

  for out_entry in targeted_entries:
    output.write(b"\n")
    output.write(jar.read(out_entry))


def ExtractEmbeddedProguardFromJar(jar, output, r8_version):
  """Extract proguard specs from a JAR file.

  Extracts version-targeted R8 rules from META-INF/com.android.tools/.
  Falls back to legacy META-INF/proguard/ if no targeted rules match.

  Args:
    jar: The JAR file to extract from.
    output: The output file to write to.
  """
  pos = output.tell()
  _ExtractTargetedR8Rules(jar, output, r8_version)
  if output.tell() > pos:
    return

  legacy_prefix = "META-INF/proguard/"
  for entry in sorted(jar.namelist()):
    if entry.startswith(legacy_prefix) and not entry.endswith("/"):
      output.write(b"\n")
      output.write(jar.read(entry))


def ExtractEmbeddedProguardFromAar(aar, output, r8_version):
  """Extract proguard specs from an AAR file.

  Reads proguard.txt from the AAR root, and also extracts R8 rules
  from META-INF/com.android.tools/ inside classes.jar.

  Args:
    aar: The AAR file to extract from.
    output: The output file to write to.
  """
  proguard_spec = "proguard.txt"
  classes_jar = "classes.jar"

  # Try targeted R8 rules from classes.jar first
  if classes_jar in aar.namelist():
    with zipfile.ZipFile(io.BytesIO(aar.read(classes_jar)), "r") as jar:
      pos = output.tell()
      _ExtractTargetedR8Rules(jar, output, r8_version)
      if output.tell() > pos:
        return

  # Fall back to legacy proguard.txt
  if proguard_spec in aar.namelist():
    output.write(aar.read(proguard_spec))
