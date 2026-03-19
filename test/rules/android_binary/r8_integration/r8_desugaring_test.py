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
import subprocess
import sys
import unittest
import zipfile


class R8DesugaringTest(unittest.TestCase):
  """Tests R8 core library desugaring integration."""

  def _get_dexdump_output(self, apk_name):
    tmp = os.environ["TEST_TMPDIR"]
    apk_directory = "test/rules/android_binary/r8_integration/java/com/desugaring"
    apk_path = os.path.join(apk_directory, apk_name)
    apk_tmp = os.path.join(tmp, apk_name)

    with zipfile.ZipFile(apk_path) as zf:
      zf.extract("classes.dex", apk_tmp)

    dexdump_proc = subprocess.run(
        [dexdump, "-d", os.path.join(apk_tmp, "classes.dex")],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    return dexdump_proc.stdout.decode()

  def test_duration_to_seconds_is_desugared(self):
    output = self._get_dexdump_output("desugaring_app_r8.apk")

    # Duration.toSeconds() (API 31) must not appear as a raw call in the DEX.
    # If present, R8 was not passed --desugared-lib and the call will cause
    # NoSuchMethodError on API 28-30 devices.
    self.assertNotIn(
        "Ljava/time/Duration;.toSeconds:()J",
        output,
    )

  def test_desugared_duration_class_present(self):
    output = self._get_dexdump_output("desugaring_app_r8.apk")

    # The DurationUser class should still be in the DEX (kept by proguard rules)
    self.assertIn(
        "Class descriptor  : 'Lcom/desugaring/DurationUser;'",
        output,
    )


if __name__ == "__main__":
  dexdump = sys.argv.pop()
  unittest.main(argv=None)
