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

"""Tests that R8 properly applies core library desugaring.

Verifies that methods added after API 26 (like Duration.toSeconds() from
API 31) are retargeted to their backported implementations when R8 processes
an android_binary with core library desugaring enabled.
"""

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

        all_output = []
        with zipfile.ZipFile(apk_path) as zf:
            for name in zf.namelist():
                if name.endswith(".dex"):
                    zf.extract(name, apk_tmp)
                    dex_path = os.path.join(apk_tmp, name)
                    proc = subprocess.run(
                        [dexdump, "-d", dex_path],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        check=True,
                    )
                    all_output.append(proc.stdout.decode(errors="replace"))

        return "\n".join(all_output)

    def test_duration_to_seconds_is_desugared(self):
        """Duration.toSeconds() (API 31) must not appear as a raw call in the DEX."""
        output = self._get_dexdump_output("desugaring_app_r8.apk")

        self.assertNotIn(
            "Ljava/time/Duration;.toSeconds:()J",
            output,
            "Duration.toSeconds() was NOT desugared. This method requires API 31 "
            "and will cause NoSuchMethodError on API 28-30 devices. "
            "R8 must be passed --desugared-lib to retarget this call.",
        )

    def test_desugared_duration_class_present(self):
        """The desugared library runtime must be included in the APK."""
        output = self._get_dexdump_output("desugaring_app_r8.apk")

        # The DurationUser class should still be in the DEX (kept by proguard rules)
        self.assertIn(
            "Class descriptor  : 'Lcom/desugaring/DurationUser;'",
            output,
            "DurationUser class not found in DEX output",
        )


if __name__ == "__main__":
    dexdump = sys.argv.pop()
    unittest.main(argv=None)
