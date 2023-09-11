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
package com.google.devtools.build.android.sandboxedsdktoolbox.clientsources;

import static java.nio.file.Files.createTempDirectory;
import static java.util.stream.Collectors.toCollection;

import androidx.privacysandbox.tools.apigenerator.PrivacySandboxApiGenerator;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/**
 * Command for generating Kotlin and Java sources for communicating with a sandboxed SDK over IPC.
 */
@Command(
    name = "generate-client-sources",
    description =
        "Generate Kotlin and Java sources for communicating with a sandboxed SDK over IPC.")
public final class GenerateClientSourcesCommand implements Runnable {

  private final PrivacySandboxApiGenerator generator = new PrivacySandboxApiGenerator();

  @Option(names = "--aidl-compiler", required = true)
  Path aidlCompilerPath;

  @Option(names = "--framework-aidl", required = true)
  Path frameworkAidlPath;

  @Option(names = "--sdk-api-descriptors", required = true)
  Path sdkApiDescriptorsPath;

  @Option(
      names = "--output-kotlin-dir",
      description = "Directory where Kotlin sources will be written.",
      required = true)
  Path outputKotlinDirPath;

  @Option(
      names = "--output-java-dir",
      description = "Directory where Java sources will be written.",
      required = true)
  Path outputJavaDirPath;

  @Override
  public void run() {
    try {
      Path apiGeneratorOutputDir = createTempDirectory("apigenerator-raw-output");
      generator.generate(
          sdkApiDescriptorsPath, aidlCompilerPath, frameworkAidlPath, apiGeneratorOutputDir);
      splitSources(apiGeneratorOutputDir, outputKotlinDirPath, outputJavaDirPath);
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to generate sources.", e);
    }
  }

  /** Split Java and Kotlin sources into different root directories. */
  private static void splitSources(
      Path sourcesDirectory, Path kotlinSourcesDirectory, Path javaSourcesDirectory)
      throws IOException {
    for (Path path : allFiles(sourcesDirectory)) {
      Path targetDir = javaSourcesDirectory;
      if (path.toString().endsWith(".kt")) {
        targetDir = kotlinSourcesDirectory;
      }
      Path targetPath = targetDir.resolve(sourcesDirectory.relativize(path));

      Files.createDirectories(targetPath.getParent());
      Files.move(path, targetPath);
    }
  }

  private static List<Path> allFiles(Path rootDirectory) throws IOException {
    try (Stream<Path> pathStream = Files.walk(rootDirectory)) {
      return pathStream.filter(Files::isRegularFile).collect(toCollection(ArrayList::new));
    }
  }

  private GenerateClientSourcesCommand() {}
}
