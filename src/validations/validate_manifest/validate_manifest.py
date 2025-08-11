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

import argparse
import sys
import xml.dom.minidom


_MIN_SDK_VERSION = 'android:minSdkVersion'


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


def ValidateManifestMinSdk(manifest, expected_min_sdk):
  min_sdk_version_string = _GetMinSdkVersion(manifest)
  if not min_sdk_version_string:
    return """
Expected manifest minSdkVersion of %s but no minSdkVersion was set

""" % expected_min_sdk
  min_sdk_version = _TryParseInt(min_sdk_version_string)
  if min_sdk_version != expected_min_sdk:
    return """
Expected manifest minSdkVersion of %s but got %s

""" % (expected_min_sdk, min_sdk_version)


def main():
  parser = argparse.ArgumentParser(
      description='Validates an android manifest xml file.'
  )
  parser.add_argument(
      '--manifest', required=True, help='Path to manifest.xml to validate.'
  )
  parser.add_argument(
      '--output', required=True, help='Output file for validation action.'
  )
  parser.add_argument(
      '--expected_min_sdk_version',
      type=int,
      default=0,
      help='Expected minSdkVersion in manifest.',
  )
  args = parser.parse_args()

  with open(args.manifest, 'rb') as manifest_file:
    manifest = manifest_file.read()

  if args.expected_min_sdk_version:
    error = ValidateManifestMinSdk(manifest, args.expected_min_sdk_version)
    if error:
      sys.stderr.write(error)
      sys.exit(1)

  with open(args.output, 'w') as output:
    output.write('')


if __name__ == '__main__':
  main()
