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

import java.io.IOException;
import java.net.URI;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;

/** Test utilities for zip files. */
public final class Zip {

  /**
   * Creates a zip file with a single entry inside of it.
   *
   * @param zipPath Path to the new zip file. If the file already exists {@link IOException} will be
   *     thrown.
   */
  public static void createZipWithSingleEntry(Path zipPath, String entryName, byte[] entryContents)
      throws IOException {
    Map<String, String> env = new HashMap<>();
    env.put("create", "true");

    URI uri = URI.create("jar:" + zipPath.toUri());
    try (FileSystem zipfs = FileSystems.newFileSystem(uri, env)) {
      Files.write(zipfs.getPath(entryName), entryContents);
    }
  }

  private Zip() {}
}
