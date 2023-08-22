# Copyright 2023 The Bazel Authors. All rights reserved.
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
import unittest
import zipfile


class R8IntegrationTest(unittest.TestCase):
  """Tests Bazel's R8 integration."""

  def _r8_integration_check(
      self, apk, expect_unused_activity_resource, expect_unused_activity_class
  ):
    tmp = os.environ["TEST_TMPDIR"]
    apk_directory = (
        "test/rules/android_binary_internal/r8_integration/java/com/basicapp"
    )
    apk_tmp = os.path.join(tmp, apk)
    classes_dex = os.path.join(apk_tmp, "classes.dex")
    with zipfile.ZipFile(os.path.join(apk_directory, apk)) as zf:
      apk_files = zf.namelist()
      zf.extract("classes.dex", apk_tmp)

    self.assertEqual(
        expect_unused_activity_resource,
        "res/layout/unused_activity.xml" in apk_files,
    )

    build_tools_dir = "external/androidsdk-supplemental/build-tools"
    build_tools_version = os.listdir(build_tools_dir)[0]
    dexdump = os.path.join(build_tools_dir, build_tools_version, "dexdump")

    dexdump_proc = subprocess.run(
        [dexdump, classes_dex],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    dexdump_stdout = str(dexdump_proc.stdout)
    self.assertEqual(
        expect_unused_activity_class,
        "Class descriptor  : 'Lcom/basicapp/UnusedActivity;'" in dexdump_stdout,
    )

    # In all cases, the Lib2WithSpecsActivity class should be in the app,
    # since lib2_proguard.cfg (an indirect dependency) specifies to keep it.
    self.assertIn(
        "Class descriptor  : 'Lcom/basicapp/Lib2WithSpecsActivity;'",
        dexdump_stdout,
    )

  def test_r8_integration(self):
    # No R8, so unused resources and unused classes should be in the app
    self._r8_integration_check(
        "basic_app_no_R8.apk",
        expect_unused_activity_resource=True,
        expect_unused_activity_class=True,
    )

    # Run R8, don't shrink, so unused class should not be in the app but unused
    # resource should remain.
    self._r8_integration_check(
        "basic_app_R8_no_shrink.apk",
        expect_unused_activity_resource=True,
        expect_unused_activity_class=False,
    )

    # Run R8 and shrinkings, so unused classes and resources should not be in
    # the app.
    self._r8_integration_check(
        "basic_app_R8_shrink.apk",
        expect_unused_activity_resource=False,
        expect_unused_activity_class=False,
    )


if __name__ == "__main__":
  unittest.main()
