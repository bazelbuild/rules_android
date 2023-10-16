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
import static com.google.common.truth.Truth.assertThat;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Runner.runCommand;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.TestData.JAVATESTS_DIR;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Zip.createZipWithSingleEntry;
import static java.util.stream.Collectors.joining;

import com.android.bundle.RuntimeEnabledSdkConfigProto.RuntimeEnabledSdk;
import com.android.bundle.RuntimeEnabledSdkConfigProto.RuntimeEnabledSdkConfig;
import com.android.bundle.SdkMetadataOuterClass.SdkMetadata;
import com.android.bundle.SdkModulesConfigOuterClass.RuntimeEnabledSdkVersion;
import com.google.common.collect.ImmutableList;
import com.google.devtools.build.android.sandboxedsdktoolbox.utils.CommandResult;
import com.google.protobuf.ExtensionRegistry;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.stream.IntStream;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class GenerateRuntimeEnabledSdkConfigCommandTest {

  @Rule public final TemporaryFolder testFolder = new TemporaryFolder();

  private static final Path TEST_DATA_DIR =
      JAVATESTS_DIR.resolve(
          Path.of(
              "com/google/devtools/build/android/sandboxedsdktoolbox",
              "runtimeenabledsdkconfig/testdata"));
  private static final Path SDK_CONFIG_JSON_PATH =
      TEST_DATA_DIR.resolve("com.example.sdkconfig.json");
  // Fake manifest XML tree file content, with extra data around the important bits.
  private static final String MANIFEST_TREE_XML_MIN_VERSION_21 =
      "should\nignore http://schemas.android.com/apk/res/android:minSdkVersion(0x0101020c)=21\n"
          + "gibberish";
  private static final String MANIFEST_TREE_XML_MIN_VERSION_26 =
      "should\nignore http://schemas.android.com/apk/res/android:minSdkVersion(0x0a01030e)=26\n"
          + "gibberish";
  /*
   The test key was generated with this command, its password is "android"
   keytool -genkeypair \
     -alias androiddebugkey \
     -dname "CN=Android Debug, O=Android, C=US" \
     -keystore test_key \
     -sigalg SHA256withDSA \
     -validity 10950
  */
  private static final Path TEST_KEY_PATH = TEST_DATA_DIR.resolve("test_key");
  private static final String TEST_KEY_CERTIFICATE_DIGEST =
      "91:8E:A3:7D:7D:D0:E0:A0:14:9F:21:28:83:95:8A:F0:80:E6:F9:7B:4D:5A:39:01:76:02:E8:"
          + "2D:7D:FF:A9:10";
  private static final RuntimeEnabledSdkVersion SDK_VERSION =
      RuntimeEnabledSdkVersion.newBuilder().setMajor(3).setMinor(2).setPatch(1).build();

  @Test
  public void generateConfig_onApi26_returnsIncreasingResourceIds() throws Exception {
    String firstPackageName = "com.example.archivedsdk1";
    String secondPackageName = "com.example.archivedsdk2";
    String digest = "example:fake:digest";

    RuntimeEnabledSdkConfig result =
        runCommandAndReturnConfig(
            MANIFEST_TREE_XML_MIN_VERSION_26,
            ImmutableList.of(
                SdkMetadata.newBuilder()
                    .setPackageName(firstPackageName)
                    .setSdkVersion(SDK_VERSION)
                    .setCertificateDigest(digest)
                    .build(),
                SdkMetadata.newBuilder()
                    .setPackageName(secondPackageName)
                    .setSdkVersion(SDK_VERSION)
                    .setCertificateDigest(digest)
                    .build()),
            ImmutableList.of());

    RuntimeEnabledSdk expectedCommonSdk =
        RuntimeEnabledSdk.newBuilder()
            .setVersionMajor(SDK_VERSION.getMajor())
            .setVersionMinor(SDK_VERSION.getMinor())
            .setBuildTimeVersionPatch(SDK_VERSION.getPatch())
            .setCertificateDigest(digest)
            .build();
    assertThat(result)
        .isEqualTo(
            RuntimeEnabledSdkConfig.newBuilder()
                .addRuntimeEnabledSdk(
                    expectedCommonSdk.toBuilder()
                        .setPackageName(firstPackageName)
                        .setResourcesPackageId(128))
                .addRuntimeEnabledSdk(
                    expectedCommonSdk.toBuilder()
                        .setPackageName(secondPackageName)
                        .setResourcesPackageId(129))
                .build());
  }

  @Test
  public void generateConfig_onApi21_returnsDecreasingResourceIds() throws Exception {
    String firstPackageName = "com.example.archivedsdk1";
    String secondPackageName = "com.example.archivedsdk2";
    String digest = "example:fake:digest";

    RuntimeEnabledSdkConfig result =
        runCommandAndReturnConfig(
            MANIFEST_TREE_XML_MIN_VERSION_21,
            ImmutableList.of(
                SdkMetadata.newBuilder()
                    .setPackageName(firstPackageName)
                    .setSdkVersion(SDK_VERSION)
                    .setCertificateDigest(digest)
                    .build(),
                SdkMetadata.newBuilder()
                    .setPackageName(secondPackageName)
                    .setSdkVersion(SDK_VERSION)
                    .setCertificateDigest(digest)
                    .build()),
            ImmutableList.of());

    RuntimeEnabledSdk expectedCommonSdk =
        RuntimeEnabledSdk.newBuilder()
            .setVersionMajor(SDK_VERSION.getMajor())
            .setVersionMinor(SDK_VERSION.getMinor())
            .setBuildTimeVersionPatch(SDK_VERSION.getPatch())
            .setCertificateDigest(digest)
            .build();
    assertThat(result)
        .isEqualTo(
            RuntimeEnabledSdkConfig.newBuilder()
                .addRuntimeEnabledSdk(
                    expectedCommonSdk.toBuilder()
                        .setPackageName(firstPackageName)
                        .setResourcesPackageId(126))
                .addRuntimeEnabledSdk(
                    expectedCommonSdk.toBuilder()
                        .setPackageName(secondPackageName)
                        .setResourcesPackageId(125))
                .build());
  }

  @Test
  public void generateConfig_forModuleConfig_usesDebugKeyDigest() throws Exception {
    String sdkArchivePackageName = "com.example.sdkarchive";
    String productionDigest = "fake:prod:digest";

    RuntimeEnabledSdkConfig result =
        runCommandAndReturnConfig(
            MANIFEST_TREE_XML_MIN_VERSION_26,
            ImmutableList.of(
                SdkMetadata.newBuilder()
                    .setPackageName(sdkArchivePackageName)
                    .setSdkVersion(SDK_VERSION)
                    .setCertificateDigest(productionDigest)
                    .build()),
            ImmutableList.of(SDK_CONFIG_JSON_PATH));

    assertThat(result)
        .isEqualTo(
            RuntimeEnabledSdkConfig.newBuilder()
                .addRuntimeEnabledSdk(
                    RuntimeEnabledSdk.newBuilder()
                        .setPackageName("com.example.sdkfrombundle")
                        .setVersionMajor(42)
                        .setVersionMinor(25)
                        .setBuildTimeVersionPatch(2)
                        .setCertificateDigest(TEST_KEY_CERTIFICATE_DIGEST)
                        .setResourcesPackageId(128))
                .addRuntimeEnabledSdk(
                    RuntimeEnabledSdk.newBuilder()
                        .setPackageName(sdkArchivePackageName)
                        .setCertificateDigest(productionDigest)
                        .setVersionMajor(SDK_VERSION.getMajor())
                        .setVersionMinor(SDK_VERSION.getMinor())
                        .setBuildTimeVersionPatch(SDK_VERSION.getPatch())
                        .setResourcesPackageId(129))
                .build());
  }

  @Test
  public void generateConfig_withoutSdks_fails() throws Exception {
    Path outputConfig = testFolder.newFile().toPath();
    ImmutableList<String> args =
        buildArgs(
            outputConfig, MANIFEST_TREE_XML_MIN_VERSION_21, ImmutableList.of(), ImmutableList.of());
    CommandResult result = runCommand(args.toArray(String[]::new));

    assertThat(result.getStatusCode()).isEqualTo(1);
    assertThat(result.getOutput())
        .contains("At least one of --sdk-module-configs or --sdk-archives must be specified.");
  }

  @Test
  public void generateConfig_for51Sdks_onApi21_fails() throws Exception {
    Path outputConfig = testFolder.newFile().toPath();

    ImmutableList<String> args =
        buildArgs(
            outputConfig,
            MANIFEST_TREE_XML_MIN_VERSION_21,
            IntStream.range(0, 51)
                .mapToObj(i -> SdkMetadata.newBuilder().setPackageName("com.example." + i).build())
                .collect(toImmutableList()),
            ImmutableList.of());
    CommandResult result = runCommand(args.toArray(String[]::new));

    assertThat(result.getStatusCode()).isEqualTo(1);
    assertThat(result.getOutput()).contains("Too many SDK dependencies (51).");
  }

  @Test
  public void generateConfig_for51Sdks_onApi26_success() throws Exception {
    Path outputConfig = testFolder.newFile().toPath();

    ImmutableList<String> args =
        buildArgs(
            outputConfig,
            MANIFEST_TREE_XML_MIN_VERSION_26,
            IntStream.range(0, 51)
                .mapToObj(i -> SdkMetadata.newBuilder().setPackageName("com.example." + i).build())
                .collect(toImmutableList()),
            ImmutableList.of());
    CommandResult result = runCommand(args.toArray(String[]::new));

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
  }

  @Test
  public void generateConfig_for129Sdks_onApi26_fails() throws Exception {
    Path outputConfig = testFolder.newFile().toPath();

    ImmutableList<String> args =
        buildArgs(
            outputConfig,
            MANIFEST_TREE_XML_MIN_VERSION_26,
            IntStream.range(0, 129)
                .mapToObj(i -> SdkMetadata.newBuilder().setPackageName("com.example." + i).build())
                .collect(toImmutableList()),
            ImmutableList.of());
    CommandResult result = runCommand(args.toArray(String[]::new));

    assertThat(result.getStatusCode()).isEqualTo(1);
    assertThat(result.getOutput()).contains("Too many SDK dependencies (129).");
  }

  @Test
  public void generateConfig_withMissingMinSdkVersion_fails() throws Exception {
    Path outputConfig = testFolder.newFile().toPath();

    ImmutableList<String> args =
        buildArgs(outputConfig, "", ImmutableList.of(), ImmutableList.of(SDK_CONFIG_JSON_PATH));
    CommandResult result = runCommand(args.toArray(String[]::new));

    assertThat(result.getStatusCode()).isEqualTo(1);
    assertThat(result.getOutput()).contains("Min SDK version missing from manifest xml tree file.");
  }

  /**
   * Runs the generate-runtime-enabled-sdk-config command with the given android manifest, sdk
   * archives and SDK module configs.
   *
   * <p>The archives are represented as a single zip with the given SDK Metadata messages inside.
   */
  private RuntimeEnabledSdkConfig runCommandAndReturnConfig(
      String manifestXmlTree,
      ImmutableList<SdkMetadata> sdkArchives,
      ImmutableList<Path> sdkModuleConfigPaths)
      throws Exception {
    Path outputConfig = testFolder.newFile().toPath();
    ImmutableList<String> args =
        buildArgs(outputConfig, manifestXmlTree, sdkArchives, sdkModuleConfigPaths);
    CommandResult result = runCommand(args.toArray(String[]::new));

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
    return readConfig(outputConfig);
  }

  private ImmutableList<String> buildArgs(
      Path outputConfig,
      String manifestXmlTree,
      ImmutableList<SdkMetadata> sdkArchives,
      ImmutableList<Path> sdkModuleConfigPaths)
      throws Exception {
    Path manifestXmlTreePath = testFolder.newFile("manifest_xml_tree.txt").toPath();
    Files.writeString(manifestXmlTreePath, manifestXmlTree);

    ImmutableList.Builder<String> args = ImmutableList.builder();
    args.add(
        "generate-runtime-enabled-sdk-config",
        "--debug-keystore",
        TEST_KEY_PATH.toString(),
        "--debug-keystore-pass",
        "android",
        "--debug-keystore-alias",
        "androiddebugkey",
        "--output-config",
        outputConfig.toString(),
        "--manifest-xml-tree",
        manifestXmlTreePath.toString());

    if (!sdkModuleConfigPaths.isEmpty()) {
      args.add(
          "--sdk-module-configs",
          sdkModuleConfigPaths.stream().map(Path::toString).collect(joining(",")));
    }

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

    return args.build();
  }

  private static RuntimeEnabledSdkConfig readConfig(Path configPath) throws IOException {
    return RuntimeEnabledSdkConfig.parseFrom(
        Files.readAllBytes(configPath), ExtensionRegistry.getEmptyRegistry());
  }
}
