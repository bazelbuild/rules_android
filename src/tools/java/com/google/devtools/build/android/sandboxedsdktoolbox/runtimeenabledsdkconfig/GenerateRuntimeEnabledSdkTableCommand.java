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
package com.google.devtools.build.android.sandboxedsdktoolbox.runtimeenabledsdkconfig;

import static com.google.common.collect.ImmutableList.toImmutableList;

import com.android.bundle.RuntimeEnabledSdkConfigProto.RuntimeEnabledSdk;
import com.android.tools.build.bundletool.splitters.RuntimeEnabledSdkTableInjector;
import com.google.common.collect.ImmutableList;
import com.google.devtools.build.android.sandboxedsdktoolbox.mixin.SdkDependenciesCommandMixin;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import picocli.CommandLine.Command;
import picocli.CommandLine.Mixin;
import picocli.CommandLine.Option;

/**
 * Command for generating the Runtime Enabled SDK table.
 *
 * <p>This file is a directory of paths to sdk metadata that is required by the Jetpack SDK Runtime
 * library. This is required for installing sandboxed SDKs on devices without the Sandbox.
 */
@Command(
    name = "generate-runtime-enabled-sdk-table",
    description =
        "Generate XML file with sandboxed SDK metadata for apps targeting devices without the"
            + " sandbox.")
public final class GenerateRuntimeEnabledSdkTableCommand implements Runnable {

  @Mixin SdkDependenciesCommandMixin sdkDependenciesMixin;

  @Option(names = "--output-table", required = true)
  Path outputTablePath;

  @Override
  public void run() {
    ImmutableList<RuntimeEnabledSdk> dependencies =
        sdkDependenciesMixin.getSdkDependencies().stream()
            .map(
                sdkInfo ->
                    RuntimeEnabledSdk.newBuilder()
                        .setPackageName(sdkInfo.getPackageName())
                        .setVersionMajor(sdkInfo.getVersion().getMajor())
                        .setVersionMinor(sdkInfo.getVersion().getMinor())
                        // The cert digest, patch version and other fields are not used to create
                        // the final table, so we can omit them.
                        .build())
            .collect(toImmutableList());
    try {
      Files.write(
          outputTablePath,
          // Calls bundletool utility class to generate the table for us. This is the same class
          // that creates the table for the build-apks command targeting AABs.
          RuntimeEnabledSdkTableInjector.generateRuntimeEnabledSdkTableBytes(dependencies));
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to write runtime-enabled SDK table.", e);
    }
  }

  private GenerateRuntimeEnabledSdkTableCommand() {}
}
