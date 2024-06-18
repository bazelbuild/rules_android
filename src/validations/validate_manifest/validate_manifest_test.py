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
Expected manifest minSdkVersion of 21 but no minSdkVersion was set

"""


MIN_SDK_TOO_LOW_ERROR = """
Expected manifest minSdkVersion of 21 but got 10

"""

MIN_SDK_BAD_ERROR = """
Expected manifest minSdkVersion of 21 but got None

"""


class ValidateManifestTest(unittest.TestCase):

  def test_no_min_sdk(self):
    self.assertEqual(
        validate_manifest.ValidateManifestMinSdk(MANIFEST_NO_MIN_SDK, 21),
        NO_MIN_SDK_ERROR,
    )

  def test_too_low_min_sdk(self):
    self.assertEqual(
        validate_manifest.ValidateManifestMinSdk(MANIFEST, 21),
        MIN_SDK_TOO_LOW_ERROR,
    )

  def test_bad_min_sdk(self):
    self.assertEqual(
        validate_manifest.ValidateManifestMinSdk(BAD_MANIFEST, 21),
        MIN_SDK_BAD_ERROR,
    )

  def test_negative(self):
    self.assertIsNone(
        validate_manifest.ValidateManifestMinSdk(MANIFEST, 10), None
    )


if __name__ == "__main__":
  unittest.main()
