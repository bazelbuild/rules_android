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
package com.google.devtools.build.android.sandboxedsdktoolbox.sdksplitproperties;

import static com.google.common.base.Preconditions.checkArgument;

import com.android.bundle.RuntimeEnabledSdkConfigProto.RuntimeEnabledSdk;
import com.android.bundle.RuntimeEnabledSdkConfigProto.RuntimeEnabledSdkConfig;
import com.android.bundle.RuntimeEnabledSdkConfigProto.SdkSplitPropertiesInheritedFromApp;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfoReader;
import com.google.devtools.build.android.sandboxedsdktoolbox.mixin.HostAppInfoMixin;
import com.google.protobuf.ExtensionRegistry;
import com.google.protobuf.util.JsonFormat;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import picocli.CommandLine.Command;
import picocli.CommandLine.Mixin;
import picocli.CommandLine.Option;

/**
 * Generates the {@link SdkSplitPropertiesInheritedFromApp} proto message for a sandboxed SDK
 * dependency of an app.
 *
 * <p>This file is used to create the SDK split added to the app in the Privacy Sandbox
 * compatibility mode. It contains information about the host app and the SDK.
 */
@Command(
    name = "generate-sdk-split-properties",
    description = "Generate the SdkSplitProperties file for a sandboxed SDK dependency of an app.")
public final class GenerateSdkSplitPropertiesCommand implements Runnable {

  @Mixin HostAppInfoMixin hostAppInfoMixin;

  @Option(names = "--runtime-enabled-sdk-config", required = true)
  Path runtimeEnabledSdkConfigPath;

  @Option(names = "--sdk-archive", required = false)
  Path sdkArchivePath;

  @Option(names = "--sdk-modules-config", required = false)
  Path sdkModuleConfigPath;

  @Option(names = "--output-properties", required = true)
  Path outputPropertiesPath;

  @Override
  public void run() {
    SdkSplitPropertiesInheritedFromApp properties =
        SdkSplitPropertiesInheritedFromApp.newBuilder()
            .setPackageName(hostAppInfoMixin.getPackageName())
            .setVersionCode(hostAppInfoMixin.getVersionCode())
            .setMinSdkVersion(hostAppInfoMixin.getMinSdkVersion())
            .setResourcesPackageId(getSdkResourceId())
            .build();
    try {
      Files.writeString(outputPropertiesPath, JsonFormat.printer().print(properties));
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to write sdk-split-properties files.", e);
    }
  }

  private int getSdkResourceId() {
    try {
      RuntimeEnabledSdkConfig config =
          RuntimeEnabledSdkConfig.parseFrom(
              Files.readAllBytes(runtimeEnabledSdkConfigPath),
              ExtensionRegistry.getEmptyRegistry());
      String sdkPackageName = getSdkPackageName();

      return config.getRuntimeEnabledSdkList().stream()
          .filter(sdk -> sdk.getPackageName().equals(sdkPackageName))
          .map(RuntimeEnabledSdk::getResourcesPackageId)
          .findFirst()
          .orElseThrow(
              () ->
                  new IllegalArgumentException(
                      "SDK mentioned in archive/bundle is not present in RuntimeEnabledSdkConfig "
                          + "file. SDK package name: "
                          + sdkPackageName));
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to read RuntimeEnabledSdkConfig file.", e);
    }
  }

  private String getSdkPackageName() {
    checkArgument(
        sdkArchivePath == null ^ sdkModuleConfigPath == null,
        "Exactly one of --sdk-archive or --sdk-modules-config must be specified.");

    if (sdkArchivePath != null) {
      return SdkInfoReader.readFromSdkArchive(sdkArchivePath).getPackageName();
    }

    return SdkInfoReader.readFromSdkModuleJsonFile(sdkModuleConfigPath).getPackageName();
  }

  private GenerateSdkSplitPropertiesCommand() {}
}
