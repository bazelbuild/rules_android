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

import static com.google.common.truth.Truth.assertThat;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Runner.runCommand;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.TestData.readFromAbsolutePath;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Zip.createZipWithSingleEntry;

import com.android.bundle.SdkMetadataOuterClass.SdkMetadata;
import com.android.bundle.SdkModulesConfigOuterClass.RuntimeEnabledSdkVersion;
import com.android.bundle.SdkModulesConfigOuterClass.SdkModulesConfig;
import com.google.common.collect.ImmutableList;
import com.google.devtools.build.android.sandboxedsdktoolbox.utils.CommandResult;
import com.google.protobuf.util.JsonFormat;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class GenerateRuntimeEnabledSdkTableCommandTest {

  @Rule public final TemporaryFolder testFolder = new TemporaryFolder();

  @Test
  public void generateTable_forMultipleSdkArchives_success() throws Exception {
    String firstPackageName = "com.example.archivedsdk1";
    String secondPackageName = "com.example.archivedsdk2";

    String tableContents =
        runCommandAndReturnTableContents(
            ImmutableList.of(
                SdkMetadata.newBuilder()
                    .setPackageName(firstPackageName)
                    .setSdkVersion(RuntimeEnabledSdkVersion.newBuilder().setMajor(42).setMinor(42))
                    .build(),
                SdkMetadata.newBuilder()
                    .setPackageName(secondPackageName)
                    .setSdkVersion(RuntimeEnabledSdkVersion.newBuilder().setMajor(1).setMinor(2))
                    .build()),
            ImmutableList.of());

    String expectedTable =
        "<runtime-enabled-sdk-table>\n"
            + "  <runtime-enabled-sdk>\n"
            + "    <package-name>com.example.archivedsdk1</package-name>\n"
            + "    <version-major>420042</version-major>\n"
            + "    <compat-config-path>RuntimeEnabledSdk-com.example.archivedsdk1/CompatSdkConfig.xml</compat-config-path>\n"
            + "  </runtime-enabled-sdk>\n"
            + "  <runtime-enabled-sdk>\n"
            + "    <package-name>com.example.archivedsdk2</package-name>\n"
            + "    <version-major>10002</version-major>\n"
            + "    <compat-config-path>RuntimeEnabledSdk-com.example.archivedsdk2/CompatSdkConfig.xml</compat-config-path>\n"
            + "  </runtime-enabled-sdk>\n"
            + "</runtime-enabled-sdk-table>";
    assertThat(tableContents).isEqualTo(expectedTable);
  }

  @Test
  public void generateTable_forMultipleSdkBundles_success() throws Exception {
    String firstPackageName = "com.example.sdkbundle1";
    String secondPackageName = "com.example.sdkbundle2";

    String tableContents =
        runCommandAndReturnTableContents(
            ImmutableList.of(),
            ImmutableList.of(
                SdkModulesConfig.newBuilder()
                    .setSdkPackageName(firstPackageName)
                    .setSdkVersion(RuntimeEnabledSdkVersion.newBuilder().setMajor(42).setMinor(42))
                    .build(),
                SdkModulesConfig.newBuilder()
                    .setSdkPackageName(secondPackageName)
                    .setSdkVersion(RuntimeEnabledSdkVersion.newBuilder().setMajor(1).setMinor(2))
                    .build()));

    String expectedTable =
        "<runtime-enabled-sdk-table>\n"
            + "  <runtime-enabled-sdk>\n"
            + "    <package-name>com.example.sdkbundle1</package-name>\n"
            + "    <version-major>420042</version-major>\n"
            + "    <compat-config-path>RuntimeEnabledSdk-com.example.sdkbundle1/CompatSdkConfig.xml</compat-config-path>\n"
            + "  </runtime-enabled-sdk>\n"
            + "  <runtime-enabled-sdk>\n"
            + "    <package-name>com.example.sdkbundle2</package-name>\n"
            + "    <version-major>10002</version-major>\n"
            + "    <compat-config-path>RuntimeEnabledSdk-com.example.sdkbundle2/CompatSdkConfig.xml</compat-config-path>\n"
            + "  </runtime-enabled-sdk>\n"
            + "</runtime-enabled-sdk-table>";
    assertThat(tableContents).isEqualTo(expectedTable);
  }

  /** Runs the generate-runtime-enabled-sdk-table command with the given RuntimeEnabledSdkConfig. */
  private String runCommandAndReturnTableContents(
      ImmutableList<SdkMetadata> sdkArchives, ImmutableList<SdkModulesConfig> sdkModulesConfigList)
      throws Exception {
    Path outputTable = testFolder.newFile().toPath();

    ImmutableList.Builder<String> args = ImmutableList.builder();
    args.add("generate-runtime-enabled-sdk-table", "--output-table", outputTable.toString());

    if (!sdkArchives.isEmpty()) {
      ArrayList<String> sdkArchivePaths = new ArrayList<>();
      for (SdkMetadata sdkMetadata : sdkArchives) {
        Path sdkArchivePath =
            testFolder.getRoot().toPath().resolve(sdkMetadata.hashCode() + ".asar");
        createZipWithSingleEntry(sdkArchivePath, "SdkMetadata.pb", sdkMetadata.toByteArray());
        sdkArchivePaths.add(sdkArchivePath.toString());
      }
      args.add("--sdk-archives", String.join(",", sdkArchivePaths));
    }

    if (!sdkModulesConfigList.isEmpty()) {
      ArrayList<String> sdkModulesConfigPaths = new ArrayList<>();
      for (SdkModulesConfig sdkModulesConfig : sdkModulesConfigList) {
        Path sdkModulesConfigPath =
            testFolder.getRoot().toPath().resolve(sdkModulesConfig.hashCode() + ".pb.json");
        Files.writeString(sdkModulesConfigPath, JsonFormat.printer().print(sdkModulesConfig));
        sdkModulesConfigPaths.add(sdkModulesConfigPath.toString());
      }
      args.add("--sdk-module-configs", String.join(",", sdkModulesConfigPaths));
    }

    CommandResult result = runCommand(args.build().toArray(String[]::new));

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
    return readFromAbsolutePath(outputTable);
  }
}
