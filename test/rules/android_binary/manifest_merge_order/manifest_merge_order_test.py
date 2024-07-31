# Copyright 2024 The Bazel Authors. All rights reserved.
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

import os
import re
import subprocess
import sys
import unittest


class ManifestMergeOrderTest(unittest.TestCase):
  """Tests Bazel's Android manifest merge order."""

  def _test_manifest_merge_order(self, apk, expected_manifest_value):

    aapt2_proc = subprocess.run(
        [aapt2, "dump", "xmltree", "--file", "AndroidManifest.xml", apk],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if aapt2_proc.returncode != 0:
      print(aapt2_proc.stdout)
      print(aapt2_proc.stderr)
      self.fail("aapt2 return code: " + str(aapt2_proc.returncode))
    match = re.search(
        r'A: http://schemas.android.com/apk/res/android:value\(0x[0-9A-Fa-f]+\)="([^"]*)"'
        r' \(Raw: ".*"\)',
        str(aapt2_proc.stdout),
    )
    self.assertIsNotNone(match)
    data_value = match.groups()[0]
    self.assertEqual(data_value, expected_manifest_value)

  def test_legacy_manifest_merge_order(self):
    self._test_manifest_merge_order(legacy_order_apk, "baz")

  def test_dependency_manifest_merge_order(self):
    self._test_manifest_merge_order(dependency_order_apk, "foo")


if __name__ == "__main__":
  legacy_order_apk = sys.argv.pop()
  dependency_order_apk = sys.argv.pop()
  aapt2 = sys.argv.pop()
  unittest.main(argv=None)
