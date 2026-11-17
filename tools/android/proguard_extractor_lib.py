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


_COM_ANDROID_TOOLS = "META-INF/com.android.tools/"


def _HasComAndroidTools(jar):
  """Whether a JAR has a META-INF/com.android.tools/ directory."""
  return any(entry.startswith(_COM_ANDROID_TOOLS) for entry in jar.namelist())


def ExtractEmbeddedProguardFromAar(aar, output):
  """Extract proguard specs from an AAR file.

  Reads proguard.txt from the AAR root. Like AGP, skips it if classes.jar has a
  META-INF/com.android.tools/ directory, even if nothing in it matches the
  current R8. R8 selects rules from classes.jar itself, so they are not
  extracted here.

  Args:
    aar: The AAR file to extract from.
    output: The output file to write to.
  """
  proguard_spec = "proguard.txt"
  classes_jar = "classes.jar"

  if classes_jar in aar.namelist():
    with zipfile.ZipFile(io.BytesIO(aar.read(classes_jar)), "r") as jar:
      if _HasComAndroidTools(jar):
        return

  if proguard_spec in aar.namelist():
    output.write(aar.read(proguard_spec))


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
