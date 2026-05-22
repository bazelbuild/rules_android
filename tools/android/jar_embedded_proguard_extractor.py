# pylint: disable=g-direct-third-party-import
# Copyright 2026 The Bazel Authors. All rights reserved.
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

from bazel_tools.tools.python.runfiles import runfiles

import os
import zipfile

# Do not edit this line. Copybara replaces it with PY2 migration helper.
from absl import app
from absl import flags

from tools.android import json_worker_wrapper
from tools.android import junction
from tools.android import proguard_extractor_lib

FLAGS = flags.FLAGS

flags.DEFINE_multi_string("input_jars", None, "Input JAR(s)")
flags.mark_flag_as_required("input_jars")
flags.DEFINE_string(
    "output_proguard_file", None, "Output parameter file for proguard"
)
flags.mark_flag_as_required("output_proguard_file")


def _Main(input_jars, output_proguard_file, r8_version = None):
  with open(output_proguard_file, "wb") as output:
    for input_jar in input_jars:
      with zipfile.ZipFile(input_jar, "r") as jar:
        proguard_extractor_lib.ExtractEmbeddedProguardFromJar(jar, output, r8_version)


def main(unused_argv):
  r = runfiles.Create()
  r8_version = None
  with open(r.Rlocation("rules_android/tools/android/r8.version"), "r") as file:
      runfile_lines = file.readlines()
      if runfile_lines:
          r8_version = runfile_lines[0].strip()

  if os.name == "nt":
    proguard_long = os.path.abspath(FLAGS.output_proguard_file)

    with junction.TempJunction(os.path.dirname(proguard_long)) as proguard_junc:
      _Main(
          [os.path.abspath(j) for j in FLAGS.input_jars],
          os.path.join(proguard_junc, os.path.basename(proguard_long)),
          r8_version,
      )
  else:
    _Main(FLAGS.input_jars, FLAGS.output_proguard_file, r8_version)


if __name__ == "__main__":
  json_worker_wrapper.wrap_worker(FLAGS, main, app.run)
