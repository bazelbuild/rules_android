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

import static com.google.common.truth.Truth.assertThat;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Runner.runCommand;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.TestData.JAVATESTS_DIR;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Zip.createZipWithSingleEntry;

import com.android.bundle.RuntimeEnabledSdkConfigProto.RuntimeEnabledSdk;
import com.android.bundle.RuntimeEnabledSdkConfigProto.RuntimeEnabledSdkConfig;
import com.android.bundle.RuntimeEnabledSdkConfigProto.SdkSplitPropertiesInheritedFromApp;
import com.android.bundle.SdkMetadataOuterClass.SdkMetadata;
import com.android.bundle.SdkModulesConfigOuterClass.SdkModulesConfig;
import com.google.common.collect.ImmutableList;
import com.google.devtools.build.android.sandboxedsdktoolbox.utils.CommandResult;
import com.google.protobuf.util.JsonFormat;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Optional;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class GenerateSdkSplitPropertiesCommandTest {
  @Rule public final TemporaryFolder testFolder = new TemporaryFolder();

  private static final Path TEST_DATA_DIR =
      JAVATESTS_DIR.resolve(
          Path.of(
              "com/google/devtools/build/android/sandboxedsdktoolbox",
              "sdksplitproperties/testdata"));
  private static final Path MANIFEST_XML_TREE_DUMP_PATH =
      TEST_DATA_DIR.resolve("valid_xmltree_dump.txt");
  private static final Path MANIFEST_XML_TREE_DUMP_WITH_DUPLICATE_VALUES_PATH =
      TEST_DATA_DIR.resolve("xmltree_dump_with_duplicate_values.txt");
  private static final String HOST_APP_PACKAGE_NAME = "com.example.host.app";
  private static final int HOST_APP_MIN_SDK_VERSION = 30;
  private static final int HOST_APP_VERSION_CODE = 42;
  private static final int SDK_RESOURCE_ID = 127;

  @Test
  public void generateProperties_withSdkArchive_succeeds() throws Exception {
    String sdkPackageName = "com.android.sdk.test";
    RuntimeEnabledSdkConfig config =
        RuntimeEnabledSdkConfig.newBuilder()
            .addRuntimeEnabledSdk(
                RuntimeEnabledSdk.newBuilder()
                    .setPackageName(sdkPackageName)
                    .setResourcesPackageId(SDK_RESOURCE_ID))
            .build();
    SdkMetadata metadata = SdkMetadata.newBuilder().setPackageName(sdkPackageName).build();

    SdkSplitPropertiesInheritedFromApp properties =
        runCommandAndReturnProperties(
            config, MANIFEST_XML_TREE_DUMP_PATH, Optional.of(metadata), Optional.empty());

    assertThat(properties)
        .isEqualTo(
            SdkSplitPropertiesInheritedFromApp.newBuilder()
                .setPackageName(HOST_APP_PACKAGE_NAME)
                .setMinSdkVersion(HOST_APP_MIN_SDK_VERSION)
                .setVersionCode(HOST_APP_VERSION_CODE)
                .setResourcesPackageId(SDK_RESOURCE_ID)
                .build());
  }

  @Test
  public void generateProperties_withModuleConfig_succeeds() throws Exception {
    String sdkPackageName = "com.android.sdk.test";
    RuntimeEnabledSdkConfig config =
        RuntimeEnabledSdkConfig.newBuilder()
            .addRuntimeEnabledSdk(
                RuntimeEnabledSdk.newBuilder()
                    .setPackageName(sdkPackageName)
                    .setResourcesPackageId(SDK_RESOURCE_ID))
            .build();
    SdkModulesConfig modulesConfig =
        SdkModulesConfig.newBuilder().setSdkPackageName(sdkPackageName).build();

    SdkSplitPropertiesInheritedFromApp properties =
        runCommandAndReturnProperties(
            config, MANIFEST_XML_TREE_DUMP_PATH, Optional.empty(), Optional.of(modulesConfig));

    assertThat(properties)
        .isEqualTo(
            SdkSplitPropertiesInheritedFromApp.newBuilder()
                .setPackageName(HOST_APP_PACKAGE_NAME)
                .setMinSdkVersion(HOST_APP_MIN_SDK_VERSION)
                .setVersionCode(HOST_APP_VERSION_CODE)
                .setResourcesPackageId(SDK_RESOURCE_ID)
                .build());
  }

  @Test
  public void generateProperties_readsManifestWithDuplicateValues_usesFirstValuesAndSucceeds()
      throws Exception {
    String sdkPackageName = "com.android.sdk.test";
    RuntimeEnabledSdkConfig config =
        RuntimeEnabledSdkConfig.newBuilder()
            .addRuntimeEnabledSdk(
                RuntimeEnabledSdk.newBuilder()
                    .setPackageName(sdkPackageName)
                    .setResourcesPackageId(SDK_RESOURCE_ID))
            .build();
    SdkMetadata metadata = SdkMetadata.newBuilder().setPackageName(sdkPackageName).build();

    SdkSplitPropertiesInheritedFromApp properties =
        runCommandAndReturnProperties(
            config,
            MANIFEST_XML_TREE_DUMP_WITH_DUPLICATE_VALUES_PATH,
            Optional.of(metadata),
            Optional.empty());

    assertThat(properties)
        .isEqualTo(
            SdkSplitPropertiesInheritedFromApp.newBuilder()
                .setPackageName(HOST_APP_PACKAGE_NAME)
                .setMinSdkVersion(HOST_APP_MIN_SDK_VERSION)
                .setVersionCode(HOST_APP_VERSION_CODE)
                .setResourcesPackageId(SDK_RESOURCE_ID)
                .build());
  }

  @Test
  public void generateProperties_withNoSdkArchiveOrModuleConfig_fails() throws Exception {
    String sdkPackageName = "com.android.sdk.test";
    RuntimeEnabledSdkConfig config =
        RuntimeEnabledSdkConfig.newBuilder()
            .addRuntimeEnabledSdk(
                RuntimeEnabledSdk.newBuilder()
                    .setPackageName(sdkPackageName)
                    .setResourcesPackageId(SDK_RESOURCE_ID))
            .build();
    ImmutableList<String> args =
        buildArgs(
            testFolder.newFile().toPath(),
            config,
            MANIFEST_XML_TREE_DUMP_PATH,
            Optional.empty(),
            Optional.empty());

    CommandResult result = runCommand(args.toArray(String[]::new));

    assertThat(result.getStatusCode()).isEqualTo(1);
    assertThat(result.getOutput())
        .contains("Exactly one of --sdk-archive or --sdk-modules-config must be specified.");
  }

  @Test
  public void generateProperties_withSdkMissingFromConfig_fails() throws Exception {
    String sdkPackageName = "com.android.sdk.test";
    RuntimeEnabledSdkConfig config =
        RuntimeEnabledSdkConfig.newBuilder()
            .addRuntimeEnabledSdk(
                RuntimeEnabledSdk.newBuilder()
                    .setPackageName("anotherSdkPackageName")
                    .setResourcesPackageId(SDK_RESOURCE_ID))
            .build();
    ImmutableList<String> args =
        buildArgs(
            testFolder.newFile().toPath(),
            config,
            MANIFEST_XML_TREE_DUMP_PATH,
            Optional.of(SdkMetadata.newBuilder().setPackageName(sdkPackageName).build()),
            Optional.empty());

    CommandResult result = runCommand(args.toArray(String[]::new));

    assertThat(result.getStatusCode()).isEqualTo(1);
    assertThat(result.getOutput())
        .contains(
            "SDK mentioned in archive/bundle is not present in RuntimeEnabledSdkConfig file. SDK"
                + " package name: com.android.sdk.test");
  }

  /**
   * Runs the generate-sdk-split-properties command with the given parameters. The resulting
   * properties are parsed from the output file and returned in proto format for easier assertion.
   */
  private SdkSplitPropertiesInheritedFromApp runCommandAndReturnProperties(
      RuntimeEnabledSdkConfig config,
      Path manifestXmlTreePath,
      Optional<SdkMetadata> sdkArchiveMetadata,
      Optional<SdkModulesConfig> sdkModulesConfig)
      throws Exception {
    Path outputProperties = testFolder.newFile().toPath();
    ImmutableList<String> args =
        buildArgs(
            outputProperties, config, manifestXmlTreePath, sdkArchiveMetadata, sdkModulesConfig);
    CommandResult result = runCommand(args.toArray(String[]::new));

    assertThat(result.getOutput()).isEmpty();
    assertThat(result.getStatusCode()).isEqualTo(0);
    SdkSplitPropertiesInheritedFromApp.Builder outputBuilder =
        SdkSplitPropertiesInheritedFromApp.newBuilder();
    JsonFormat.parser().merge(Files.readString(outputProperties), outputBuilder);
    return outputBuilder.build();
  }

  private ImmutableList<String> buildArgs(
      Path outputPropertiesPath,
      RuntimeEnabledSdkConfig config,
      Path manifestXmlTreePath,
      Optional<SdkMetadata> sdkArchiveMetadata,
      Optional<SdkModulesConfig> sdkModulesConfig)
      throws Exception {

    ImmutableList.Builder<String> args = ImmutableList.builder();
    args.add(
        "generate-sdk-split-properties", "--output-properties", outputPropertiesPath.toString());

    Path configPath = testFolder.newFile("runtime-enabled-sdk-config.pb").toPath();
    Files.write(configPath, config.toByteArray());
    args.add("--runtime-enabled-sdk-config", configPath.toString());

    args.add("--manifest-xml-tree", manifestXmlTreePath.toString());

    if (sdkArchiveMetadata.isPresent()) {
      Path sdkArchivePath = testFolder.getRoot().toPath().resolve("sdk-archive.asar");
      createZipWithSingleEntry(
          sdkArchivePath, "SdkMetadata.pb", sdkArchiveMetadata.get().toByteArray());
      args.add("--sdk-archive", sdkArchivePath.toString());
    }

    if (sdkModulesConfig.isPresent()) {
      Path sdkModulesConfigPath =
          testFolder.getRoot().toPath().resolve("sdk-modules-config.pb.json");
      Files.writeString(sdkModulesConfigPath, JsonFormat.printer().print(sdkModulesConfig.get()));
      args.add("--sdk-modules-config", sdkModulesConfigPath.toString());
    }

    return args.build();
  }
}
