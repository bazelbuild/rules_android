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
package com.google.devtools.build.android.sandboxedsdktoolbox.mixin;

import static com.google.common.collect.ImmutableSet.toImmutableSet;
import static com.google.devtools.build.android.sandboxedsdktoolbox.mixin.CertificateDigestGenerator.generateCertificateDigest;

import com.google.common.collect.ImmutableSet;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfo;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfoReader;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;
import picocli.CommandLine.Option;

/**
 * Parses command line options that describe SDK dependencies, coming from SDK archives or bundles.
 */
public final class SdkDependenciesCommandMixin {

  private List<Path> sdkModuleConfigPaths = new ArrayList<>();
  private List<Path> sdkArchivePaths = new ArrayList<>();
  private Path debugKeystorePath;
  private String debugKeystorePassword;
  private String debugKeystoreAlias;

  public ImmutableSet<SdkInfo> getSdkDependencies() {
    checkValid();

    return Stream.concat(
            sdkModuleConfigPaths.stream().map(SdkInfoReader::readFromSdkModuleJsonFile),
            sdkArchivePaths.stream().map(SdkInfoReader::readFromSdkArchive))
        .collect(toImmutableSet());
  }

  public String getDebugCertificateDigest() {
    return generateCertificateDigest(debugKeystorePath, debugKeystorePassword, debugKeystoreAlias);
  }

  @Option(names = "--sdk-module-configs", split = ",", required = false)
  void setSdkModuleConfigPaths(List<Path> sdkModuleConfigPaths) {
    this.sdkModuleConfigPaths = sdkModuleConfigPaths;
  }

  @Option(names = "--sdk-archives", split = ",", required = false)
  void setSdkArchivePaths(List<Path> sdkArchivePaths) {
    this.sdkArchivePaths = sdkArchivePaths;
  }

  @Option(names = "--debug-keystore", required = true)
  void setDebugKeystorePath(Path debugKeystorePath) {
    this.debugKeystorePath = debugKeystorePath;
  }

  @Option(names = "--debug-keystore-pass", required = true)
  void setDebugKeystorePassword(String debugKeystorePassword) {
    this.debugKeystorePassword = debugKeystorePassword;
  }

  @Option(names = "--debug-keystore-alias", required = true)
  void setDebugKeystoreAlias(String debugKeystoreAlias) {
    this.debugKeystoreAlias = debugKeystoreAlias;
  }

  private void checkValid() {
    if (sdkModuleConfigPaths.isEmpty() && sdkArchivePaths.isEmpty()) {
      throw new IllegalArgumentException(
          "At least one of --sdk-module-configs or --sdk-archives must be specified.");
    }
  }

  private SdkDependenciesCommandMixin() {}
}
