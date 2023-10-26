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

import static com.google.common.base.Preconditions.checkArgument;

import com.android.bundle.RuntimeEnabledSdkConfigProto.RuntimeEnabledSdk;
import com.android.bundle.RuntimeEnabledSdkConfigProto.RuntimeEnabledSdkConfig;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfo;
import com.google.devtools.build.android.sandboxedsdktoolbox.mixin.DebugKeystoreCommandMixin;
import com.google.devtools.build.android.sandboxedsdktoolbox.mixin.HostAppInfoMixin;
import com.google.devtools.build.android.sandboxedsdktoolbox.mixin.SdkDependenciesCommandMixin;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import picocli.CommandLine.Command;
import picocli.CommandLine.Mixin;
import picocli.CommandLine.Option;

/** Command for extracting API descriptors from a sandboxed SDK Archive. */
@Command(
    name = "generate-runtime-enabled-sdk-config",
    description =
        "Generate the RuntimeEnabledSdkConfig file for app bundles that depend on sandboxed SDKs.")
public final class GenerateRuntimeEnabledSdkConfigCommand implements Runnable {

  @Option(names = "--output-config", required = true)
  Path outputConfigPath;

  @Mixin SdkDependenciesCommandMixin sdkDependenciesMixin;
  @Mixin DebugKeystoreCommandMixin debugKeystoreMixin;
  @Mixin HostAppInfoMixin hostAppInfoMixin;

  @Override
  public void run() {
    ResourceIdGenerator generator = new ResourceIdGenerator(hostAppInfoMixin.getMinSdkVersion());
    checkArgument(
        sdkDependenciesMixin.getSdkDependencies().size() <= generator.maxResourceIds(),
        "Too many SDK dependencies (%s). For apps with min SDK 26 and above the maximum is 127. "
            + "For older versions it's 50.",
        sdkDependenciesMixin.getSdkDependencies().size());

    String debugCertificateDigest = debugKeystoreMixin.getDebugCertificateDigest();

    RuntimeEnabledSdkConfig.Builder builder = RuntimeEnabledSdkConfig.newBuilder();
    for (SdkInfo sdkInfo : sdkDependenciesMixin.getSdkDependencies()) {
      builder.addRuntimeEnabledSdk(
          RuntimeEnabledSdk.newBuilder()
              .setPackageName(sdkInfo.getPackageName())
              .setVersionMajor(sdkInfo.getVersion().getMajor())
              .setVersionMinor(sdkInfo.getVersion().getMinor())
              .setBuildTimeVersionPatch(sdkInfo.getVersion().getPatch())
              .setCertificateDigest(sdkInfo.getCertificateDigest().orElse(debugCertificateDigest))
              .setResourcesPackageId(generator.nextResourceId()));
    }

    try {
      Files.write(outputConfigPath, builder.build().toByteArray());
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to write runtime-enabled SDK config file.", e);
    }
  }

  private GenerateRuntimeEnabledSdkConfigCommand() {}
}
