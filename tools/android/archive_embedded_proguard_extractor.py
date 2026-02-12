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
"""A tool for extracting proguard spec files from a JAR or AAR."""

from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import io
import os
import zipfile

# Do not edit this line. Copybara replaces it with PY2 migration helper.
from absl import app
from absl import flags

from tools.android import json_worker_wrapper
from tools.android import junction

FLAGS = flags.FLAGS

flags.DEFINE_string("input_archive", None, "Input JAR or AAR")
flags.mark_flag_as_required("input_archive")
flags.DEFINE_string("output_proguard_file", None,
                    "Output parameter file for proguard")
flags.mark_flag_as_required("output_proguard_file")
flags.DEFINE_enum("archive_type", None, ["jar", "aar"],
                  "Type of archive: jar or aar")
flags.mark_flag_as_required("archive_type")


def _ExtractR8Rules(jar, output):
  """Extract R8 rules from META-INF/com.android.tools/ inside a JAR.

  Handles subdirectories like r8-from-X-upto-Y/. All matching files are
  concatenated into the output, sorted by path for determinism.
  """
  meta_inf_prefix = "META-INF/com.android.tools/"
  for entry in sorted(jar.namelist()):
    if entry.startswith(meta_inf_prefix) and not entry.endswith("/"):
      output.write(b"\n")
      output.write(jar.read(entry))


def ExtractEmbeddedProguardFromJar(jar, output):
  """Extract proguard specs from a JAR file."""
  legacy_prefix = "META-INF/proguard/"
  r8_prefix = "META-INF/com.android.tools/"

  for entry in sorted(jar.namelist()):
    if not entry.endswith("/") and (
        entry.startswith(legacy_prefix) or entry.startswith(r8_prefix)):
      output.write(b"\n")
      output.write(jar.read(entry))


def ExtractEmbeddedProguardFromAar(aar, output):
  """Extract proguard specs from an AAR file."""
  proguard_spec = "proguard.txt"
  classes_jar = "classes.jar"

  if proguard_spec in aar.namelist():
    output.write(aar.read(proguard_spec))

  # For AARs, META-INF/com.android.tools/ lives inside classes.jar
  if classes_jar in aar.namelist():
    with zipfile.ZipFile(io.BytesIO(aar.read(classes_jar)), "r") as jar:
      _ExtractR8Rules(jar, output)


def _Main(input_archive, output_proguard_file, archive_type):
  with zipfile.ZipFile(input_archive, "r") as archive:
    with open(output_proguard_file, "wb") as output:
      if archive_type == "jar":
        ExtractEmbeddedProguardFromJar(archive, output)
      else:
        ExtractEmbeddedProguardFromAar(archive, output)


def main(unused_argv):
  if os.name == "nt":
    archive_long = os.path.abspath(FLAGS.input_archive)
    proguard_long = os.path.abspath(FLAGS.output_proguard_file)

    with junction.TempJunction(os.path.dirname(archive_long)) as archive_junc:
      with junction.TempJunction(
          os.path.dirname(proguard_long)) as proguard_junc:
        _Main(
            os.path.join(archive_junc, os.path.basename(archive_long)),
            os.path.join(proguard_junc, os.path.basename(proguard_long)),
            FLAGS.archive_type)
  else:
    _Main(FLAGS.input_archive, FLAGS.output_proguard_file, FLAGS.archive_type)


if __name__ == "__main__":
  json_worker_wrapper.wrap_worker(FLAGS, main, app.run)
