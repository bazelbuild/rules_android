# pylint: disable=g-direct-third-party-import
# Copyright 2022 The Bazel Authors. All rights reserved.
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
"""AndroidManifest tool to enforce a floor on the minSdkVersion attribute.

Ensures that the minSdkVersion attribute is >= than the specified floor,
and if the attribute is either not specified or less than the floor,
sets it to the floor.
"""

import os
import sys

from absl import app
from absl import flags
import lxml.etree as ET

BUMP = "bump"
SET_DEFAULT = "set_default"

USES_SDK = "uses-sdk"
MIN_SDK_ATTRIB = "{http://schemas.android.com/apk/res/android}minSdkVersion"

FLAGS = flags.FLAGS

flags.DEFINE_enum(
    "action",
    None,
    [BUMP, SET_DEFAULT],
    f"Action to perform: either {BUMP} or {SET_DEFAULT}")
flags.DEFINE_string(
    "manifest",
    None,
    "AndroidManifest.xml of the instrumentation APK")
flags.DEFINE_integer(
    "min_sdk_floor",
    0,
    "Min SDK floor",
    lower_bound=0)
# Needed for SET_DEFAULT
flags.DEFINE_string(
    "default_min_sdk",
    None,
    "Default min SDK")
# Needed for BUMP and  SET_DEFAULT
flags.DEFINE_string(
    "output",
    None,
    f"Output AndroidManifest.xml to generate, only needed for {BUMP}")
flags.DEFINE_string("log", None, "Path to write the log to")


class MinSdkError(Exception):
  """Raised when there is a problem with the min SDK attribute in AndroidManifest.xml."""


def ParseNamespaces(xml_content):
  """Parse namespaces first to keep the prefix.

  Args:
    xml_content: str, the contents of the AndroidManifest.xml file
  """
  # Always register the android namespace first. This will be overriden by
  # any other definition in the manifest.
  ET.register_namespace("android", "http://schemas.android.com/apk/res/android")
  ns_parser = ET.XMLPullParser(events=["start-ns"])
  ns_parser.feed(xml_content)
  ns_parser.close()
  for _, ns_tuple in ns_parser.read_events():
    try:
      ET.register_namespace(ns_tuple[0], ns_tuple[1])
    except ValueError:
      pass


def GetXmlString(root, pre_root_comments):
  """Returns the XML string for a node + any comments to appear before the node."""
  if not pre_root_comments:
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)

  result = b""
  for i, x in enumerate(pre_root_comments):
    xml_declaration = i == 0
    result = (
        result
        + ET.tostring(x, encoding="utf-8", xml_declaration=xml_declaration)
        + b"\n"
    )
  result = result + ET.tostring(root, encoding="utf-8", xml_declaration=False)
  return result


def _BumpMinSdk(xml_content, min_sdk_floor):
  """Checks the min SDK in xml_content and replaces with min_sdk_floor if needed.

  Args:
    xml_content: str, the contents of the AndroidManifest.xml file
    min_sdk_floor: int, the min SDK floor

  Returns:
    A tuple with the following elements:
    - str: The xml contents of the manifest with the min SDK floor enforced.
      This string will be equal to the input if the min SDK is already not less
      than the floor.
    - str: log message of action taken
  """
  if min_sdk_floor == 0:
    return xml_content, "No min SDK floor specified. Manifest unchanged."

  ParseNamespaces(xml_content)

  root = ET.fromstring(xml_content)
  pre_root_comments = [
      x for x in root.itersiblings(tag=ET.Comment, preceding=True)
  ]

  uses_sdk = root.find(USES_SDK)
  if uses_sdk is None:
    ET.SubElement(root, USES_SDK, {MIN_SDK_ATTRIB: str(min_sdk_floor)})
    return (
        GetXmlString(root, pre_root_comments),
        "No uses-sdk element found while floor is specified "
        + f"({min_sdk_floor}). Min SDK added.",
    )

  min_sdk = uses_sdk.get(MIN_SDK_ATTRIB)
  if min_sdk is None:
    uses_sdk.set(MIN_SDK_ATTRIB, str(min_sdk_floor))
    return (
        GetXmlString(root, pre_root_comments),
        "No minSdkVersion attribute found while floor is specified"
        + f"({min_sdk_floor}). Min SDK added.",
    )

  try:
    min_sdk_int = int(min_sdk)
  except ValueError:
    return (
        xml_content,
        f"Placeholder used for the minSdkVersion attribute ({min_sdk}). "
        + "Manifest unchanged.")

  if min_sdk_int < min_sdk_floor:
    uses_sdk.set(MIN_SDK_ATTRIB, str(min_sdk_floor))
    return (
        GetXmlString(root, pre_root_comments),
        f"minSdkVersion attribute specified in the manifest ({min_sdk}) "
        + f"is less than the floor ({min_sdk_floor}). Min SDK replaced.",
    )
  return (
      xml_content,
      f"minSdkVersion attribute specified in the manifest ({min_sdk}) "
      + f"is not less than the floor ({min_sdk_floor}). Manifest unchanged.")


def _SetDefaultMinSdk(xml_content, default_min_sdk):
  """Checks the min SDK in xml_content and replaces with default_min_sdk if it is not already set.

  Args:
    xml_content: str, the contents of the AndroidManifest.xml file
    default_min_sdk: str, can be set to either a number or an unreleased version
      full name

  Returns:
    A tuple with the following elements:
    - str: The xml contents of the manifest with the min SDK floor enforced.
      This string will be equal to the input if the min SDK is already set.
    - str: log message of action taken
  """
  if default_min_sdk is None:
    return xml_content, ("No default min SDK floor specified. Manifest "
                         "unchanged.")

  ParseNamespaces(xml_content)

  root = ET.fromstring(xml_content)
  uses_sdk = root.find(USES_SDK)
  if uses_sdk is None:
    ET.SubElement(root, USES_SDK, {MIN_SDK_ATTRIB: default_min_sdk})
    return (
        ET.tostring(root, encoding="utf-8", xml_declaration=True),
        "No uses-sdk element found while default is specified. "
        + f"Min SDK ({default_min_sdk}) added.")

  min_sdk = uses_sdk.get(MIN_SDK_ATTRIB)
  if min_sdk is None:
    uses_sdk.set(MIN_SDK_ATTRIB, str(default_min_sdk))
    return (
        ET.tostring(root, encoding="utf-8", xml_declaration=True),
        "No minSdkVersion attribute found while default is specified"
        + f"({default_min_sdk}). Min SDK set to default.")

  return (
      xml_content,
      f"minSdkVersion attribute specified in the manifest ({min_sdk}) "
      + ". Manifest unchanged.")


def main(unused_argv):
  manifest_path = FLAGS.manifest
  with open(manifest_path, "rb") as f:
    manifest = f.read()

  if FLAGS.action == BUMP:
    output_path = FLAGS.output
    dirname = os.path.dirname(output_path)
    if not os.path.exists(dirname):
      os.makedirs(dirname)

    out_contents, log_message = _BumpMinSdk(manifest, FLAGS.min_sdk_floor)
    with open(output_path, "wb") as f:
      f.write(out_contents)

  elif FLAGS.action == SET_DEFAULT:
    output_path = FLAGS.output
    dirname = os.path.dirname(output_path)
    if not os.path.exists(dirname):
      os.makedirs(dirname)

    out_contents, log_message = _SetDefaultMinSdk(
        manifest, FLAGS.default_min_sdk
    )
    with open(output_path, "wb") as f:
      f.write(out_contents)
  else:
    sys.exit(f"Action must be either {BUMP} or {SET_DEFAULT}")

  if FLAGS.log is not None:
    log_path = FLAGS.log
    dirname = os.path.dirname(log_path)
    if not os.path.exists(dirname):
      os.makedirs(dirname)
    with open(log_path, "w") as f:
      f.write(log_message)

if __name__ == "__main__":
  app.run(main)
