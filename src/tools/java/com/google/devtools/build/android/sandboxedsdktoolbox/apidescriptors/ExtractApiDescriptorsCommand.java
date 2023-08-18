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

import static java.nio.file.Files.createTempDirectory;

import androidx.privacysandbox.tools.apipackager.PrivacySandboxApiPackager;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/** Command that Extracts API descriptors from a sandboxed SDK's classpath. */
@Command(
    name = "extract-api-descriptors",
    description = "Extracts API descriptors from a sandboxed SDK's classpath.")
public final class ExtractApiDescriptorsCommand implements Runnable {

  @Option(names = "--sdk-deploy-jar", required = true)
  Path sdkDeployJarPath;

  @Option(names = "--output-sdk-api-descriptors", required = true)
  Path outputSdkApiDescriptorsPath;

  private final PrivacySandboxApiPackager packager = new PrivacySandboxApiPackager();

  @Override
  public void run() {
    try {
      Path sdkClasspath = unzipSdkDeployJar();
      packager.packageSdkDescriptors(sdkClasspath, outputSdkApiDescriptorsPath);
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to package SDK API descriptors.", e);
    }
  }

  private Path unzipSdkDeployJar() throws IOException {
    Path sdkClasspath = createTempDirectory("tmp-sdk-classpath");
    try (InputStream inputStream = Files.newInputStream(sdkDeployJarPath);
        ZipInputStream zipInputStream = new ZipInputStream(inputStream)) {

      ZipEntry entry = null;
      while ((entry = zipInputStream.getNextEntry()) != null) {
        Path entryPath = sdkClasspath.resolve(entry.getName()).normalize();
        if (entry.isDirectory()) {
          continue;
        }

        if (!entryPath.startsWith(sdkClasspath)) {
          throw new IOException(
              String.format("Invalid entry name in SDK classpath zip: %s", entry.getName()));
        }

        Files.createDirectories(entryPath.getParent());
        Files.copy(zipInputStream, entryPath);
      }
    }
    return sdkClasspath;
  }

  private ExtractApiDescriptorsCommand() {}
}
