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
import zipfile


def ExtractR8Rules(jar, output):
  """Extract R8 rules from META-INF/com.android.tools/ inside a JAR.

  Handles subdirectories like r8-from-X-upto-Y/. All matching files are
  concatenated into the output, sorted by path for determinism.

  Args:
    jar: The JAR file to extract from.
    output: The output file to write to.
  """
  meta_inf_prefix = "META-INF/com.android.tools/"
  for entry in sorted(jar.namelist()):
    if entry.startswith(meta_inf_prefix) and not entry.endswith("/"):
      output.write(b"\n")
      output.write(jar.read(entry))


def ExtractEmbeddedProguardFromJar(jar, output):
  """Extract proguard specs from a JAR file.

  Reads both legacy META-INF/proguard/ and R8-targeted
  META-INF/com.android.tools/ entries.

  Args:
    jar: The JAR file to extract from.
    output: The output file to write to.
  """
  legacy_prefix = "META-INF/proguard/"
  r8_prefix = "META-INF/com.android.tools/"

  for entry in sorted(jar.namelist()):
    if not entry.endswith("/") and (
        entry.startswith(legacy_prefix) or entry.startswith(r8_prefix)
    ):
      output.write(b"\n")
      output.write(jar.read(entry))


def ExtractEmbeddedProguardFromAar(aar, output):
  """Extract proguard specs from an AAR file.

  Reads proguard.txt from the AAR root, and also extracts R8 rules
  from META-INF/com.android.tools/ inside classes.jar.

  Args:
    aar: The AAR file to extract from.
    output: The output file to write to.
  """
  proguard_spec = "proguard.txt"
  classes_jar = "classes.jar"

  if proguard_spec in aar.namelist():
    output.write(aar.read(proguard_spec))

  # For AARs, META-INF/com.android.tools/ lives inside classes.jar
  if classes_jar in aar.namelist():
    with zipfile.ZipFile(io.BytesIO(aar.read(classes_jar)), "r") as jar:
      ExtractR8Rules(jar, output)


def ExtractEmbeddedProguardFromAarLegacy(aar, output):
  """Extract proguard specs from an AAR file (legacy behavior).

  Only reads proguard.txt from the AAR root. Does not extract R8 rules
  from classes.jar.

  Args:
    aar: The AAR file to extract from.
    output: The output file to write to.
  """
  proguard_spec = "proguard.txt"

  if proguard_spec in aar.namelist():
    output.write(aar.read(proguard_spec))
