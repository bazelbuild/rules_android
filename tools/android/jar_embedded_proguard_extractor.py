# pylint: disable=g-direct-third-party-import
# Copyright 2021 The Bazel Authors. All rights reserved.
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
"""A tool for extracting proguard spec files from a JAR."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import os
import zipfile

# Do not edit this line. Copybara replaces it with PY2 migration helper.
from absl import app
from absl import flags

from tools.android import json_worker_wrapper
from tools.android import junction

FLAGS = flags.FLAGS

flags.DEFINE_string("input_jar", None, "Input JAR")
flags.mark_flag_as_required("input_jar")
flags.DEFINE_string("output_proguard_file", None,
                    "Output parameter file for proguard")
flags.mark_flag_as_required("output_proguard_file")


def ExtractEmbeddedProguard(jar, output):
  """Extract proguard specs from a JAR file."""
  legacy_prefix = "META-INF/proguard/"
  r8_prefix = "META-INF/com.android.tools/"

  for entry in sorted(jar.namelist()):
    if not entry.endswith("/") and (
        entry.startswith(legacy_prefix) or entry.startswith(r8_prefix)):
      output.write(b"\n")
      output.write(jar.read(entry))


def _Main(input_jar, output_proguard_file):
  with zipfile.ZipFile(input_jar, "r") as jar:
    with open(output_proguard_file, "wb") as output:
      ExtractEmbeddedProguard(jar, output)


def main(unused_argv):
  if os.name == "nt":
    jar_long = os.path.abspath(FLAGS.input_jar)
    proguard_long = os.path.abspath(FLAGS.output_proguard_file)

    with junction.TempJunction(os.path.dirname(jar_long)) as jar_junc:
      with junction.TempJunction(
          os.path.dirname(proguard_long)) as proguard_junc:
        _Main(
            os.path.join(jar_junc, os.path.basename(jar_long)),
            os.path.join(proguard_junc, os.path.basename(proguard_long)))
  else:
    _Main(FLAGS.input_jar, FLAGS.output_proguard_file)


if __name__ == "__main__":
  json_worker_wrapper.wrap_worker(FLAGS, main, app.run)
