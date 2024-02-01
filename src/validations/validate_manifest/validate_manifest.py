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
"""Validates an android manifest xml file."""

import sys
import xml.dom.minidom

from absl import app
from absl import flags

_MANIFEST = flags.DEFINE_string('manifest', None,
                                'Path to manifest.xml to validate.')
_OUTPUT = flags.DEFINE_string('output', None,
                              'Output file for validation action.')
_VALIDATE_MULTIDEX_MINSDK = flags.DEFINE_boolean(
    'validate_multidex', True, 'Whether to validate minSdkVersion for multidex')
_EXPECTED_MIN_SDK = flags.DEFINE_integer('expected_min_sdk_version', 0,
                                         'Expected minSdkVersion in manifest.')

_MIN_SDK_VERSION = 'android:minSdkVersion'

_LOLLIPOP_SDK_VERSION = 21


def _GetMinSdkVersion(manifest):
  dom = xml.dom.minidom.parseString(manifest)
  for element in dom.getElementsByTagName('uses-sdk'):
    if element.hasAttribute(_MIN_SDK_VERSION):
      return element.getAttribute(_MIN_SDK_VERSION)


def _TryParseInt(value):
  try:
    return int(value)
  except ValueError:
    return None


def ValidateManifestMinSdkVersionForNativeMultidex(manifest):
  """Validates that an Android manifest's minSdkVersion supports native multidex.

  Args:
    manifest: the XML manifest of the main APK as a string

  Returns:
    The reason the manifest is invalid, or None.
  """

  min_sdk_version = _GetMinSdkVersion(manifest)
  if not min_sdk_version:
    return """
Enabling multidex='native' is only supported on SDK version %d and newer; minSdkVersion is not set and defaults to 1.

Use multidex='legacy' instead if support for earlier SDK versions is required

""" % (_LOLLIPOP_SDK_VERSION)
  min_sdk_version = _TryParseInt(min_sdk_version)
  if not min_sdk_version:
    return None
  if min_sdk_version < _LOLLIPOP_SDK_VERSION:
    return """
Enabling multidex='native' is only supported on SDK version %d and newer; minSdkVersion is set to %d.

Use multidex='legacy' instead if support for earlier SDK versions is required

""" % (_LOLLIPOP_SDK_VERSION, min_sdk_version)
  return None


def ValidateManifestMinSdk(manifest, expected_min_sdk):
  min_sdk_version = _TryParseInt(_GetMinSdkVersion(manifest))
  if min_sdk_version != expected_min_sdk:
    return """
 Expected manifest minSdkVersion of %s but got %s

 """ % (expected_min_sdk, min_sdk_version)


def main(argv):
  if len(argv) > 1:
    raise app.UsageError('Too many command-line arguments.')

  with open(_MANIFEST.value, 'rb') as manifest_file:
    manifest = manifest_file.read()

  if _VALIDATE_MULTIDEX_MINSDK.value:
    error = ValidateManifestMinSdkVersionForNativeMultidex(manifest)
    if error:
      sys.stderr.write(error)
      sys.exit(1)

  if _EXPECTED_MIN_SDK.value:
    error = ValidateManifestMinSdk(manifest, _EXPECTED_MIN_SDK.value)
    if error:
      sys.stderr.write(error)
      sys.exit(1)

  with open(_OUTPUT.value, 'w') as output:
    output.write('')


if __name__ == '__main__':
  app.run(main)
