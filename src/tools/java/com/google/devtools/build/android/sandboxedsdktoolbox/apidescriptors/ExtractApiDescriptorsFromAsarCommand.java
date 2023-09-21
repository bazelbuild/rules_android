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
package com.google.devtools.build.android.sandboxedsdktoolbox.apidescriptors;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/** Command for extracting API descriptors from a sandboxed SDK Archive. */
@Command(
    name = "extract-api-descriptors-from-asar",
    description = "Extract API descriptors from a sandboxed SDK Archive.")
public final class ExtractApiDescriptorsFromAsarCommand implements Runnable {

  private static final String API_DESCRIPTOR_ZIP_ENTRY_PATH = "sdk-interface-descriptors.jar";

  @Option(names = "--asar", required = true)
  Path asarPath;

  @Option(names = "--output-sdk-api-descriptors", required = true)
  Path outputSdkApiDescriptorsPath;

  @Override
  public void run() {
    URI uri = URI.create("jar:" + asarPath.toUri());
    try (FileSystem zipfs = FileSystems.newFileSystem(uri, new HashMap<String, String>())) {
      Path descriptorsInZip = zipfs.getPath(API_DESCRIPTOR_ZIP_ENTRY_PATH);
      if (!Files.exists(descriptorsInZip)) {
        throw new IllegalStateException(
            String.format("Could not find %s in %s", API_DESCRIPTOR_ZIP_ENTRY_PATH, asarPath));
      }
      Files.copy(descriptorsInZip, outputSdkApiDescriptorsPath);
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to extract SDK API descriptors.", e);
    }
  }

  private ExtractApiDescriptorsFromAsarCommand() {}
}
