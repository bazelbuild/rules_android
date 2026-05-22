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
"""Tests for jar_embedded_proguard_extractor."""

import io
import os
import unittest
import zipfile

from tools.android import proguard_extractor_lib


class JarEmbeddedProguardExtractorTest(unittest.TestCase):
  """Unit tests for JAR proguard extraction."""

  def setUp(self):
    super(JarEmbeddedProguardExtractorTest, self).setUp()
    os.chdir(os.environ["TEST_TMPDIR"])

  def testNoProguardSpecs(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())

  def testLegacyMetaInfProguard(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/rules.pro", "-keep class A")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class A", proguard_file.read())

  def testMultipleLegacyFiles(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/rules1.pro", "-keep class A")
    jar.writestr("META-INF/proguard/rules2.pro", "-keep class B")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class A\n-keep class B", proguard_file.read())

  def testTargetedR8RulesMatchingVersion(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr(
        "META-INF/com.android.tools/r8-from-8.0.0-upto-9.0.0/rules.pro",
        "-keep class C",
    )
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class C", proguard_file.read())

  def testTargetedR8RulesNotMatchingVersion(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr(
        "META-INF/com.android.tools/r8-from-1.0.0-upto-2.0.0/rules.pro",
        "-keep class C",
    )
    jar.writestr("META-INF/proguard/rules.pro", "-keep class legacy")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class legacy", proguard_file.read())

  def testTargetedR8RulesPreferredOverLegacy(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr(
        "META-INF/com.android.tools/r8-from-8.0.0-upto-9.0.0/rules.pro",
        "-keep class targeted",
    )
    jar.writestr("META-INF/proguard/rules.pro", "-keep class legacy")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class targeted", proguard_file.read())

  def testVersionAtLowerBoundInclusive(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr(
        "META-INF/com.android.tools/r8-from-8.9.35-upto-9.0.0/rules.pro",
        "-keep class exact",
    )
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class exact", proguard_file.read())

  def testVersionAtUpperBoundExclusive(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr(
        "META-INF/com.android.tools/r8-from-8.0.0-upto-8.9.35/rules.pro",
        "-keep class excluded",
    )
    jar.writestr("META-INF/proguard/rules.pro", "-keep class legacy")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class legacy", proguard_file.read())

  def testMultipleVersionedDirsOnlyMatchingIncluded(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr(
        "META-INF/com.android.tools/r8-from-1.0.0-upto-2.0.0/rules.pro",
        "-keep class old",
    )
    jar.writestr(
        "META-INF/com.android.tools/r8-from-8.0.0-upto-9.0.0/rules.pro",
        "-keep class current",
    )
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class current", proguard_file.read())

  def testIgnoresDirectoryEntries(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/", "")
    jar.writestr("META-INF/proguard/rules.pro", "-keep class H")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class H", proguard_file.read())

  def testIgnoresUnrelatedMetaInf(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/MANIFEST.MF", "Manifest-Version: 1.0")
    jar.writestr("META-INF/services/com.example.Spi", "com.example.SpiImpl")
    jar.writestr("com/example/Foo.class", "classdata")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())


  def testNoneR8VersionFallsBackToLegacy(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr(
        "META-INF/com.android.tools/r8-from-8.0.0-upto-9.0.0/rules.pro",
        "-keep class targeted",
    )
    jar.writestr("META-INF/proguard/rules.pro", "-keep class legacy")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, proguard_file, None)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class legacy", proguard_file.read())


if __name__ == "__main__":
  unittest.main()
