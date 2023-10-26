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

import static com.google.devtools.build.android.sandboxedsdktoolbox.sdkdependenciesmanifest.AndroidManifestWriter.writeManifest;

import com.google.devtools.build.android.sandboxedsdktoolbox.mixin.DebugKeystoreCommandMixin;
import com.google.devtools.build.android.sandboxedsdktoolbox.mixin.SdkDependenciesCommandMixin;
import java.nio.file.Path;
import picocli.CommandLine.Command;
import picocli.CommandLine.Mixin;
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

  @Option(names = "--output-manifest", required = true)
  Path outputManifestPath;

  @Mixin SdkDependenciesCommandMixin sdkDependenciesMixin;
  @Mixin DebugKeystoreCommandMixin debugKeystoreMixin;

  @Override
  public void run() {
    writeManifest(
        manifestPackage,
        debugKeystoreMixin.getDebugCertificateDigest(),
        sdkDependenciesMixin.getSdkDependencies(),
        outputManifestPath);
  }

  private GenerateSdkDependenciesManifestCommand() {}
}
