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
  """Parses the numeric prefix of a version, e.g. "9.5.2-dev" or "8.0.0-alpha01"."""
  match = re.match(r"(\d+(?:\.\d+)*)", ver or "")
  if not match:
    return None
  return tuple(int(x) for x in match.group(1).split("."))


_R8_RULES_PREFIX = "META-INF/com.android.tools/"
_R8_RULES_DIR = re.compile(r"r8(?:-from-([^:@/]+?))?(?:-upto-([^:@/]+?))?")


def _r8_rules_dir_matches(directory, r8_version):
  """Whether a META-INF/com.android.tools/ directory targets r8_version.

  Mirrors AGP's configDirMatchesVersion: r8, r8-from-<X>, r8-upto-<Y> and
  r8-from-<X>-upto-<Y>, case-insensitive, with an inclusive lower and exclusive
  upper bound. A bound that can't be parsed is no constraint. proguard*
  directories target ProGuard and never match.
  """
  match = _R8_RULES_DIR.fullmatch(directory.lower())
  if not match:
    return False
  lower_bound, upper_bound = (_parse_version(b) for b in match.groups())
  if lower_bound and r8_version < lower_bound:
    return False
  if upper_bound and r8_version >= upper_bound:
    return False
  return True


def _R8RuleEntries(jar):
  """Returns the R8-targeted rule files in a JAR, for any R8 version."""
  entries = []
  for entry in sorted(jar.namelist()):
    if not entry.startswith(_R8_RULES_PREFIX) or entry.endswith("/"):
      continue
    directory = entry[len(_R8_RULES_PREFIX):].split("/", 1)[0]
    if _R8_RULES_DIR.fullmatch(directory.lower()):
      entries.append((directory, entry))
  return entries


def _ExtractTargetedR8Rules(jar, output, r8_version):
  """Extracts the R8-targeted rules matching r8_version.

  Like AGP, R8-targeted rules take precedence over legacy rules whenever a JAR
  has any, even if none of them match r8_version.

  Returns:
    Whether the JAR's R8-targeted rules were used, so legacy rules must be
    skipped. False if it has none or r8_version is unknown.
  """
  version = _parse_version(r8_version)
  entries = _R8RuleEntries(jar)
  if not version or not entries:
    return False
  for directory, entry in entries:
    if _r8_rules_dir_matches(directory, version):
      output.write(b"\n")
      output.write(jar.read(entry))
  return True


def ExtractEmbeddedProguardFromJar(jar, output, r8_version):
  """Extract proguard specs from a JAR file.

  Extracts the R8-targeted rules under META-INF/com.android.tools/ that match
  r8_version. Uses the legacy META-INF/proguard/ rules if the JAR has no
  R8-targeted rules or r8_version is unknown.

  Args:
    jar: The JAR file to extract from.
    output: The output file to write to.
    r8_version: The R8 version label, or None if unknown.
  """
  if _ExtractTargetedR8Rules(jar, output, r8_version):
    return

  legacy_prefix = "META-INF/proguard/"
  for entry in sorted(jar.namelist()):
    if entry.startswith(legacy_prefix) and not entry.endswith("/"):
      output.write(b"\n")
      output.write(jar.read(entry))


def ExtractEmbeddedProguardFromAar(aar, output, r8_version, extract_r8_rules=True):
  """Extract proguard specs from an AAR file.

  Extracts the R8-targeted rules in classes.jar that match r8_version. Like
  AGP, uses proguard.txt from the AAR root instead if classes.jar has no
  R8-targeted rules, r8_version is unknown, or extract_r8_rules is False.

  Args:
    aar: The AAR file to extract from.
    output: The output file to write to.
    r8_version: The R8 version label, or None if unknown.
    extract_r8_rules: Whether to consider R8-targeted rules in classes.jar.
  """
  proguard_spec = "proguard.txt"
  classes_jar = "classes.jar"

  if extract_r8_rules and classes_jar in aar.namelist():
    with zipfile.ZipFile(io.BytesIO(aar.read(classes_jar)), "r") as jar:
      if _ExtractTargetedR8Rules(jar, output, r8_version):
        return

  if proguard_spec in aar.namelist():
    output.write(aar.read(proguard_spec))
