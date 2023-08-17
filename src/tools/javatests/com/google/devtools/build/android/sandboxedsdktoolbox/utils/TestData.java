/*
 * Copyright 2023 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.google.devtools.build.android.sandboxedsdktoolbox.utils;

import static java.nio.charset.StandardCharsets.UTF_8;

import java.nio.file.Files;
import java.nio.file.Path;

/** Utilities for test data. */
public final class TestData {

  /** Path to the javatests directory in runfiles. */
  public static final Path JAVATESTS_DIR =
      Path.of(
          System.getenv("TEST_SRCDIR"),
          "/build_bazel_rules_android/src/tools/javatests/");

  /** Reads the contents of a file, assuming its path is absolute. */
  public static String readFromAbsolutePath(Path absolutePath) throws Exception {
    return String.join("\n", Files.readAllLines(absolutePath, UTF_8));
  }

  private TestData() {}
}
