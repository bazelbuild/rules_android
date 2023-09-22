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

import static com.google.common.truth.Truth.assertThat;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Runner.runCommand;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.TestData.JAVATESTS_DIR;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.TestData.readFromAbsolutePath;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Zip.createZipWithSingleEntry;

import com.android.bundle.SdkMetadataOuterClass.SdkMetadata;
import com.google.devtools.build.android.sandboxedsdktoolbox.utils.CommandResult;
import com.google.protobuf.util.JsonFormat;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class GenerateSdkDependenciesManifestCommandTest {

  @Rule public final TemporaryFolder testFolder = new TemporaryFolder();

  private static final Path TEST_DATA_DIR =
      JAVATESTS_DIR.resolve(
          Path.of(
              "com/google/devtools/build/android/sandboxedsdktoolbox",
              "sdkdependenciesmanifest/testdata"));
  private static final Path FIRST_SDK_CONFIG_JSON_PATH =
      TEST_DATA_DIR.resolve("com.example.firstsdkconfig.json");
  private static final Path SECOND_SDK_CONFIG_JSON_PATH =
      TEST_DATA_DIR.resolve("com.example.secondsdkconfig.json");
  private static final Path ARCHIVE_CONFIG_JSON_PATH =
      TEST_DATA_DIR.resolve("com.example.archivedsdkmetadata.json");

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

  @Test
  public void generateManifest_forSingleSdkModuleConfig_success() throws Exception {
    String manifestPackage = "com.example.generatedmanifest";
    Path outputFile = testFolder.newFile().toPath();

    CommandResult result =
        runCommand(
            "generate-sdk-dependencies-manifest",
            "--manifest-package",
            manifestPackage,
            "--sdk-module-configs",
            FIRST_SDK_CONFIG_JSON_PATH.toString(),
            "--debug-keystore",
            TEST_KEY_PATH.toString(),
            "--debug-keystore-pass",
            "android",
            "--debug-keystore-alias",
            "androiddebugkey",
            "--output-manifest",
            outputFile.toString());

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
    assertThat(readFromAbsolutePath(outputFile))
        .isEqualTo(readFromAbsolutePath(TEST_DATA_DIR.resolve("expected_manifest_single_sdk.xml")));
  }

  @Test
  public void generateManifest_forMultipleSdkModuleConfigs_success() throws Exception {
    String manifestPackage = "com.example.generatedmanifest";
    String configPaths =
        String.format("%s,%s", FIRST_SDK_CONFIG_JSON_PATH, SECOND_SDK_CONFIG_JSON_PATH);
    Path outputFile = testFolder.newFile().toPath();

    CommandResult result =
        runCommand(
            "generate-sdk-dependencies-manifest",
            "--manifest-package",
            manifestPackage,
            "--sdk-module-configs",
            configPaths,
            "--debug-keystore",
            TEST_KEY_PATH.toString(),
            "--debug-keystore-pass",
            "android",
            "--debug-keystore-alias",
            "androiddebugkey",
            "--output-manifest",
            outputFile.toString());

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
    assertThat(readFromAbsolutePath(outputFile))
        .isEqualTo(
            readFromAbsolutePath(TEST_DATA_DIR.resolve("expected_manifest_multiple_sdks.xml")));
  }

  @Test
  public void generateManifest_forSdksAndArchives_success() throws Exception {
    String manifestPackage = "com.example.generatedmanifest";
    // Create a zip with a single file containing the SdkMetadata proto message, serialized.
    Path archiveConfigPath = testFolder.getRoot().toPath().resolve("sdk.asar");
    createZipWithSingleEntry(archiveConfigPath, "SdkMetadata.pb", readSdkMetadata().toByteArray());
    Path outputFile = testFolder.newFile().toPath();

    CommandResult result =
        runCommand(
            "generate-sdk-dependencies-manifest",
            "--manifest-package",
            manifestPackage,
            "--sdk-module-configs",
            FIRST_SDK_CONFIG_JSON_PATH.toString(),
            "--sdk-archives",
            archiveConfigPath.toString(),
            "--debug-keystore",
            TEST_KEY_PATH.toString(),
            "--debug-keystore-pass",
            "android",
            "--debug-keystore-alias",
            "androiddebugkey",
            "--output-manifest",
            outputFile.toString());

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
    assertThat(readFromAbsolutePath(outputFile))
        .isEqualTo(
            readFromAbsolutePath(TEST_DATA_DIR.resolve("expected_manifest_with_archived_sdk.xml")));
  }

  private static SdkMetadata readSdkMetadata() throws IOException {
    SdkMetadata.Builder metadata = SdkMetadata.newBuilder();
    JsonFormat.parser().merge(Files.newBufferedReader(ARCHIVE_CONFIG_JSON_PATH), metadata);
    return metadata.build();
  }
}
