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
"""Tests for aar_embedded_proguard_extractor."""

import io
import os
import unittest
import zipfile

from tools.android import aar_embedded_proguard_extractor


class AarEmbeddedProguardExtractor(unittest.TestCase):
  """Unit tests for aar_embedded_proguard_extractor.py."""

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
    aar_embedded_proguard_extractor.ExtractEmbeddedProguard(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())

  def testWithProguardTxt(self):
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("proguard.txt", "hello world")
    proguard_file = io.BytesIO()
    aar_embedded_proguard_extractor.ExtractEmbeddedProguard(aar, proguard_file)
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
    aar_embedded_proguard_extractor.ExtractEmbeddedProguard(aar, proguard_file)
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
    aar_embedded_proguard_extractor.ExtractEmbeddedProguard(aar, proguard_file)
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
    aar_embedded_proguard_extractor.ExtractEmbeddedProguard(aar, proguard_file)
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
    aar_embedded_proguard_extractor.ExtractEmbeddedProguard(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class F", proguard_file.read())

  def testNoClassesJarNoR8Rules(self):
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("some_other_file.txt", "data")
    proguard_file = io.BytesIO()
    aar_embedded_proguard_extractor.ExtractEmbeddedProguard(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())

  def testClassesJarWithoutR8Rules(self):
    classes_jar = self._makeClassesJar({
        "com/example/Foo.class": "classdata",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    aar_embedded_proguard_extractor.ExtractEmbeddedProguard(aar, proguard_file)
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())


if __name__ == "__main__":
  unittest.main()
