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
package com.google.devtools.build.android.sandboxedsdktoolbox.sdkdependenciesmanifest;

import static com.google.common.collect.ImmutableSet.toImmutableSet;
import static com.google.devtools.build.android.sandboxedsdktoolbox.sdkdependenciesmanifest.AndroidManifestWriter.writeManifest;
import static com.google.devtools.build.android.sandboxedsdktoolbox.sdkdependenciesmanifest.CertificateDigestGenerator.generateCertificateDigest;

import com.google.common.collect.ImmutableSet;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfo;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfoReader;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/** Command for generating SDK dependencies manifest. */
@Command(
    name = "generate-sdk-dependencies-manifest",
    description =
        "Generates an Android manifest with <uses-sdk-library> tags from the given SDK bundles "
            + "or archives.")
public final class GenerateSdkDependenciesManifestCommand implements Runnable {

  @Option(names = "--manifest-package", required = true)
  String manifestPackage;

  @Option(names = "--sdk-module-configs", split = ",", required = false)
  List<Path> sdkModuleConfigPaths = new ArrayList<>();

  @Option(names = "--sdk-archives", split = ",", required = false)
  List<Path> sdkArchivePaths = new ArrayList<>();

  @Option(names = "--debug-keystore", required = true)
  Path debugKeystorePath;

  @Option(names = "--debug-keystore-pass", required = true)
  String debugKeystorePassword;

  @Option(names = "--debug-keystore-alias", required = true)
  String debugKeystoreAlias;

  @Option(names = "--output-manifest", required = true)
  Path outputManifestPath;

  @Override
  public void run() {
    if (sdkModuleConfigPaths.isEmpty() && sdkArchivePaths.isEmpty()) {
      throw new IllegalArgumentException(
          "At least one of --sdk-module-configs or --sdk-archives must be specified.");
    }

    ImmutableSet<SdkInfo> configSet =
        Stream.concat(
                sdkModuleConfigPaths.stream().map(SdkInfoReader::readFromSdkModuleJsonFile),
                sdkArchivePaths.stream().map(SdkInfoReader::readFromSdkArchive))
            .collect(toImmutableSet());

    String certificateDigest =
        generateCertificateDigest(debugKeystorePath, debugKeystorePassword, debugKeystoreAlias);

    writeManifest(manifestPackage, certificateDigest, configSet, outputManifestPath);
  }

  private GenerateSdkDependenciesManifestCommand() {}
}
