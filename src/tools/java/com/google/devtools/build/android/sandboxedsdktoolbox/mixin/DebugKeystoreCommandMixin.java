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

import static com.google.devtools.build.android.sandboxedsdktoolbox.mixin.CertificateDigestGenerator.generateCertificateDigest;

import java.nio.file.Path;
import picocli.CommandLine.Option;

/** Parses command line options defining a debug keystore. */
public final class DebugKeystoreCommandMixin {

  private Path debugKeystorePath;
  private String debugKeystorePassword;
  private String debugKeystoreAlias;

  public String getDebugCertificateDigest() {
    return generateCertificateDigest(debugKeystorePath, debugKeystorePassword, debugKeystoreAlias);
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

  private DebugKeystoreCommandMixin() {}
}
