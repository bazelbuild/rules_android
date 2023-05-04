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

"""Tool to merge the <dist /> element from a feature manifest into the main manifest."""

import xml.etree.ElementTree as ET

from absl import app
from absl import flags

_MAIN_MANIFEST = flags.DEFINE_string("main_manifest", None,
                                     "Input main manifestl")
_FEATURE_MANIFEST = flags.DEFINE_string("feature_manifest", None,
                                        "Output feature manifest")
_TITLE = flags.DEFINE_string("feature_title", None, "Feature title")
_OUT = flags.DEFINE_string("out", None, "Output manifest")


def _register_namespace(f):
  """Registers namespaces in ET global state and returns dict of namspaces."""
  ns = {}
  with open(f) as xml:
    ns_parser = ET.XMLPullParser(events=["start-ns"])
    ns_parser.feed(xml.read())
    ns_parser.close()
    for _, ns_tuple in ns_parser.read_events():
      try:
        ET.register_namespace(ns_tuple[0], ns_tuple[1])
        ns[ns_tuple[0]] = ns_tuple[1]
      except ValueError:
        pass
  return ns


def main(argv):
  if len(argv) > 1:
    raise app.UsageError("Too many command-line arguments.")

  # Parse namespaces first to keep the prefix.
  ns = {}
  ns.update(_register_namespace(_MAIN_MANIFEST.value))
  ns.update(_register_namespace(_FEATURE_MANIFEST.value))

  main_manifest = ET.parse(_MAIN_MANIFEST.value)
  feature_manifest = ET.parse(_FEATURE_MANIFEST.value)

  dist = feature_manifest.find("dist:module", ns)
  dist.set("{%s}title" % ns["dist"], _TITLE.value)
  main_manifest.getroot().append(dist)

  main_manifest.write(_OUT.value, encoding="utf-8", xml_declaration=True)


if __name__ == "__main__":
  app.run(main)
