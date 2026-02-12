# Copyright 2021 The Bazel Authors. All rights reserved.
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

from tools.android import jar_embedded_proguard_extractor


class JarEmbeddedProguardExtractor(unittest.TestCase):
  """Unit tests for jar_embedded_proguard_extractor.py."""

  def setUp(self):
    super(JarEmbeddedProguardExtractor, self).setUp()
    os.chdir(os.environ["TEST_TMPDIR"])

  def testNoProguardSpecs(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    proguard_file = io.BytesIO()
    jar_embedded_proguard_extractor.ExtractEmbeddedProguard(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())

  def testLegacyMetaInfProguard(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/rules.pro", "-keep class A")
    proguard_file = io.BytesIO()
    jar_embedded_proguard_extractor.ExtractEmbeddedProguard(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class A", proguard_file.read())

  def testMultipleLegacyFiles(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/rules1.pro", "-keep class A")
    jar.writestr("META-INF/proguard/rules2.pro", "-keep class B")
    proguard_file = io.BytesIO()
    jar_embedded_proguard_extractor.ExtractEmbeddedProguard(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class A\n-keep class B", proguard_file.read())

  def testR8Rules(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/com.android.tools/r8/rules.pro", "-keep class C")
    proguard_file = io.BytesIO()
    jar_embedded_proguard_extractor.ExtractEmbeddedProguard(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class C", proguard_file.read())

  def testR8RulesVersionedSubdirs(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr(
        "META-INF/com.android.tools/r8-from-8.0.0/rules.pro", "-keep class D")
    jar.writestr(
        "META-INF/com.android.tools/r8-upto-8.0.0/rules.pro", "-keep class E")
    proguard_file = io.BytesIO()
    jar_embedded_proguard_extractor.ExtractEmbeddedProguard(jar, proguard_file)
    proguard_file.seek(0)
    # Sorted by path: r8-from-8.0.0 before r8-upto-8.0.0
    self.assertEqual(
        b"\n-keep class D\n-keep class E", proguard_file.read())

  def testLegacyAndR8RulesCombined(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/rules.pro", "-keep class F")
    jar.writestr("META-INF/com.android.tools/r8/rules.pro", "-keep class G")
    proguard_file = io.BytesIO()
    jar_embedded_proguard_extractor.ExtractEmbeddedProguard(jar, proguard_file)
    proguard_file.seek(0)
    # Sorted by path: META-INF/com.android.tools before META-INF/proguard
    self.assertEqual(
        b"\n-keep class G\n-keep class F", proguard_file.read())

  def testIgnoresDirectoryEntries(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/", "")
    jar.writestr("META-INF/com.android.tools/", "")
    jar.writestr("META-INF/com.android.tools/r8/", "")
    jar.writestr("META-INF/com.android.tools/r8/rules.pro", "-keep class H")
    proguard_file = io.BytesIO()
    jar_embedded_proguard_extractor.ExtractEmbeddedProguard(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class H", proguard_file.read())

  def testIgnoresUnrelatedMetaInf(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/MANIFEST.MF", "Manifest-Version: 1.0")
    jar.writestr("META-INF/services/com.example.Spi", "com.example.SpiImpl")
    jar.writestr("com/example/Foo.class", "classdata")
    proguard_file = io.BytesIO()
    jar_embedded_proguard_extractor.ExtractEmbeddedProguard(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())


if __name__ == "__main__":
  unittest.main()
