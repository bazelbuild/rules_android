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
"""Tests for validate_manifest."""

import unittest
from src.validations.validate_manifest import validate_manifest

MANIFEST = """<?xml version='1.0' encoding='utf-8'?>
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.google.android.apps.testapp"
    android:versionCode="70"
    android:versionName="1.0">
  <uses-sdk android:minSdkVersion="10"/>
</manifest>
"""

MANIFEST_NO_MIN_SDK = """<?xml version='1.0' encoding='utf-8'?>
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.google.android.apps.testapp"
    android:versionCode="70"
    android:versionName="1.0">
  <uses-sdk/>
</manifest>
"""

MANIFEST_NO_USES_SDK = """<?xml version='1.0' encoding='utf-8'?>
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.google.android.apps.testapp"
    android:versionCode="70"
    android:versionName="1.0">
</manifest>
"""

BAD_MANIFEST = """<?xml version='1.0' encoding='utf-8'?>
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.google.android.apps.testapp"
    android:versionCode="70"
    android:versionName="1.0">
  <uses-sdk android:minSdkVersion="hello"/>
</manifest>
"""

NO_MIN_SDK_ERROR = """
Enabling multidex='native' is only supported on SDK version 21 and newer; minSdkVersion is not set and defaults to 1.

Use multidex='legacy' instead if support for earlier SDK versions is required

"""


class ValidateManifestTest(unittest.TestCase):

  def test_no_min_sdk(self):
    self.assertEqual(
        validate_manifest.ValidateManifestMinSdkVersionForNativeMultidex(
            MANIFEST_NO_MIN_SDK), NO_MIN_SDK_ERROR)
    self.assertEqual(
        validate_manifest.ValidateManifestMinSdkVersionForNativeMultidex(
            MANIFEST_NO_USES_SDK), NO_MIN_SDK_ERROR)

  def test_give_me_a_name(self):
    self.assertEqual(
        validate_manifest.ValidateManifestMinSdkVersionForNativeMultidex(
            MANIFEST), """
Enabling multidex='native' is only supported on SDK version 21 and newer; minSdkVersion is set to 10.

Use multidex='legacy' instead if support for earlier SDK versions is required

""")

  def test_negative(self):
    self.assertIsNone(
        validate_manifest.ValidateManifestMinSdkVersionForNativeMultidex(
            BAD_MANIFEST), None)


if __name__ == '__main__':
  unittest.main()
