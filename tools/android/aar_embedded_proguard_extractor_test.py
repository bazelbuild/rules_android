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

from tools.android import proguard_extractor_lib


class AarEmbeddedProguardExtractorTest(unittest.TestCase):
  """Unit tests for AAR proguard extraction."""

  def setUp(self):
    super(AarEmbeddedProguardExtractorTest, self).setUp()
    os.chdir(os.environ["TEST_TMPDIR"])

  def make_classes_jar(self, entries):
    jar_buf = io.BytesIO()
    with zipfile.ZipFile(jar_buf, "w") as jar:
      for path, content in entries.items():
        jar.writestr(path, content)
    return jar_buf.getvalue()

  def testNoProguardTxt(self):
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromAar(aar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())

  def testWithProguardTxt(self):
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("proguard.txt", "hello world")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromAar(aar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"hello world", proguard_file.read())

  def testTargetedR8RulesFromClassesJar(self):
    classes_jar = self.make_classes_jar({
        "META-INF/com.android.tools/r8-from-8.0.0-upto-9.0.0/rules.pro": "-keep class A",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromAar(aar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class A", proguard_file.read())

  def testTargetedR8RulesPreferredOverProguardTxt(self):
    classes_jar = self.make_classes_jar({
        "META-INF/com.android.tools/r8-from-8.0.0-upto-9.0.0/rules.pro": "-keep class targeted",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("proguard.txt", "-keep class legacy")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromAar(aar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"\n-keep class targeted", proguard_file.read())

  def testFallsBackToProguardTxtWhenNoVersionMatch(self):
    classes_jar = self.make_classes_jar({
        "META-INF/com.android.tools/r8-from-1.0.0-upto-2.0.0/rules.pro": "-keep class old",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("proguard.txt", "-keep class legacy")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromAar(aar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"-keep class legacy", proguard_file.read())

  def testNoClassesJarFallsBackToProguardTxt(self):
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("proguard.txt", "-keep class legacy")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromAar(aar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"-keep class legacy", proguard_file.read())

  def testClassesJarWithoutR8Rules(self):
    classes_jar = self.make_classes_jar({
        "com/example/Foo.class": "classdata",
    })
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("proguard.txt", "-keep class legacy")
    aar.writestr("classes.jar", classes_jar)
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromAar(aar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"-keep class legacy", proguard_file.read())

  def testNoClassesJarNoProguardTxt(self):
    aar = zipfile.ZipFile(io.BytesIO(), "w")
    aar.writestr("some_other_file.txt", "data")
    proguard_file = io.BytesIO()
    proguard_extractor_lib.ExtractEmbeddedProguardFromAar(aar, proguard_file, "8.9.35")
    proguard_file.seek(0)
    self.assertEqual(b"", proguard_file.read())


if __name__ == "__main__":
  unittest.main()
