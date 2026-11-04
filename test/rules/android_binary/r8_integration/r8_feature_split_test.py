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

"""Tests R8 optimizing a binary together with a feature module with code."""

import os
import re
import subprocess
import sys
import unittest
import zipfile


def _classes(dexdump, dex_zip, name, prefix=""):
  classes = set()
  out_dir = os.path.join(os.environ["TEST_TMPDIR"], name)
  with zipfile.ZipFile(dex_zip) as archive:
    dex_files = [
        n for n in archive.namelist() if n.startswith(prefix) and n.endswith(".dex")
    ]
    for dex_file in dex_files:
      path = archive.extract(dex_file, out_dir)
      # dexdump prints string data as raw bytes, which need not be UTF-8.
      result = subprocess.run(
          [dexdump, path], capture_output=True, text=True, errors="replace", check=True
      )
      classes.update(re.findall(r"Class descriptor\s*: '(L[^']+;)'", result.stdout))
  return dex_files, classes


class R8FeatureSplitTest(unittest.TestCase):

  def setUp(self):
    super().setUp()
    base_files, self.base = _classes(DEXDUMP, BASE_DEX_ZIP, "base")
    feature_files, self.feature = _classes(DEXDUMP, FEATURE_DEX_ZIP, "feature")
    self.assertTrue(base_files, "R8 emitted no base DEX files")
    self.assertTrue(feature_files, "R8 emitted no feature DEX files")

  def test_feature_code_is_only_in_feature(self):
    self.assertIn("Lcom/basicapp/FeatureActivity;", self.feature)
    self.assertNotIn("Lcom/basicapp/FeatureActivity;", self.base)

  def test_base_code_is_only_in_base(self):
    self.assertIn("Lcom/basicapp/BasicActivity;", self.base)
    self.assertNotIn("Lcom/basicapp/BasicActivity;", self.feature)

  def test_code_shared_with_base_is_only_in_base(self):
    self.assertIn("Lcom/basicapp/SharedHelper;", self.base)
    self.assertNotIn("Lcom/basicapp/SharedHelper;", self.feature)

  def test_no_class_is_in_both(self):
    self.assertEqual(set(), self.base & self.feature)

  def test_bundle_packages_dex_per_module(self):
    _, bundle_base = _classes(DEXDUMP, BUNDLE, "bundle_base", "base/dex/")
    _, bundle_feature = _classes(
        DEXDUMP, BUNDLE, "bundle_feature", "basic_feature/dex/"
    )
    self.assertIn("Lcom/basicapp/BasicActivity;", bundle_base)
    self.assertIn("Lcom/basicapp/SharedHelper;", bundle_base)
    self.assertEqual({"Lcom/basicapp/FeatureActivity;"}, bundle_feature)


if __name__ == "__main__":
  DEXDUMP, BUNDLE, *dex_zips = sys.argv[1:]
  (FEATURE_DEX_ZIP,) = [p for p in dex_zips if "_features/" in p]
  (BASE_DEX_ZIP,) = [p for p in dex_zips if "_features/" not in p]
  del sys.argv[1:]
  unittest.main()
