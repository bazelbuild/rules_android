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
"""Tests for archive_embedded_proguard_extractor."""

import io
import os
import unittest
import zipfile

from tools.android import archive_embedded_proguard_extractor


class JarEmbeddedProguardExtractor(unittest.TestCase):
  """Unit tests for JAR extraction in archive_embedded_proguard_extractor.py."""

  def setUp(self):
    super(JarEmbeddedProguardExtractor, self).setUp()
    os.chdir(os.environ["TEST_TMPDIR"])

  def testNoProguardSpecs(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromJar(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())

  def testLegacyMetaInfProguard(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/rules.pro", "-keep class A")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromJar(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class A", proguard_file.read())

  def testMultipleLegacyFiles(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/rules1.pro", "-keep class A")
    jar.writestr("META-INF/proguard/rules2.pro", "-keep class B")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromJar(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class A\n-keep class B", proguard_file.read())

  def testR8Rules(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/com.android.tools/r8/rules.pro", "-keep class C")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromJar(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class C", proguard_file.read())

  def testR8RulesVersionedSubdirs(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr(
        "META-INF/com.android.tools/r8-from-8.0.0/rules.pro", "-keep class D")
    jar.writestr(
        "META-INF/com.android.tools/r8-upto-8.0.0/rules.pro", "-keep class E")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromJar(jar, proguard_file)
    proguard_file.seek(0)
    # Sorted by path: r8-from-8.0.0 before r8-upto-8.0.0
    self.assertEqual(
        b"\n-keep class D\n-keep class E", proguard_file.read())

  def testLegacyAndR8RulesCombined(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/proguard/rules.pro", "-keep class F")
    jar.writestr("META-INF/com.android.tools/r8/rules.pro", "-keep class G")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromJar(jar, proguard_file)
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
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromJar(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class H", proguard_file.read())

  def testIgnoresUnrelatedMetaInf(self):
    jar = zipfile.ZipFile(io.BytesIO(), "w")
    jar.writestr("META-INF/MANIFEST.MF", "Manifest-Version: 1.0")
    jar.writestr("META-INF/services/com.example.Spi", "com.example.SpiImpl")
    jar.writestr("com/example/Foo.class", "classdata")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromJar(jar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())


class AarEmbeddedProguardExtractor(unittest.TestCase):
  """Unit tests for AAR extraction in archive_embedded_proguard_extractor.py."""

  # Python 2 alias
  if not hasattr(unittest.TestCase, "assertCountEqual"):

    def assertCountEqual(self, *args):
      return self.assertItemsEqual(*args)

  def setUp(self):
    super(AarEmbeddedProguardExtractor, self).setUp()
    os.chdir(os.environ["TEST_TMPDIR"])

  def testNoProguardTxt(self):
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromAar(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())

  def testWithProguardTxt(self):
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("proguard.txt", "hello world")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromAar(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"hello world", proguard_file.read())

  def _makeClassesJar(self, entries):
    """Create an in-memory classes.jar with the given {path: content} entries."""
    jar_buf = io.BytesIO()
    with zipfile.ZipFile(jar_buf, "w") as jar:
      for path, content in entries.items():
        jar.writestr(path, content)
    return jar_buf.getvalue()

  def testR8RulesFromClassesJar(self):
    classes_jar = self._makeClassesJar({
        "META-INF/com.android.tools/r8/rules.pro": "-keep class A",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromAar(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class A", proguard_file.read())

  def testR8RulesFromVersionedSubdirs(self):
    classes_jar = self._makeClassesJar({
        "META-INF/com.android.tools/r8-from-8.0.0/rules.pro": "-keep class B",
        "META-INF/com.android.tools/r8-upto-8.0.0/rules.pro": "-keep class C",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromAar(aar, proguard_file)
    proguard_file.seek(0)
    # Sorted by path: r8-from-8.0.0 before r8-upto-8.0.0
    self.assertEqual(
        b"\n-keep class B\n-keep class C", proguard_file.read())

  def testR8RulesAndProguardTxtCombined(self):
    classes_jar = self._makeClassesJar({
        "META-INF/com.android.tools/r8/rules.pro": "-keep class D",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("proguard.txt", "-keep class E")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromAar(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(
        b"-keep class E\n-keep class D", proguard_file.read())

  def testR8RulesIgnoresDirectoryEntries(self):
    classes_jar = self._makeClassesJar({
        "META-INF/com.android.tools/": "",
        "META-INF/com.android.tools/r8/": "",
        "META-INF/com.android.tools/r8/rules.pro": "-keep class F",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromAar(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class F", proguard_file.read())

  def testNoClassesJarNoR8Rules(self):
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("some_other_file.txt", "data")
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromAar(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())

  def testClassesJarWithoutR8Rules(self):
    classes_jar = self._makeClassesJar({
        "com/example/Foo.class": "classdata",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    archive_embedded_proguard_extractor.ExtractEmbeddedProguardFromAar(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())


if __name__ == "__main__":
  unittest.main()
