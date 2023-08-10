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
package com.google.devtools.build.android.sandboxedsdktoolbox;

import static com.google.common.truth.Truth.assertThat;
import static java.nio.charset.StandardCharsets.UTF_8;
import static java.util.stream.Collectors.joining;

import com.google.common.io.Files;
import java.io.File;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.nio.file.Paths;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;
import picocli.CommandLine;

@RunWith(JUnit4.class)
public final class GenerateSdkDependenciesManifestCommandTest {

  @Rule public final TemporaryFolder testFolder = new TemporaryFolder();

  private static final String TEST_DATA_DIR =
      "/build_bazel_rules_android/src/tools/javatests/com/google/devtools/"
          + "build/android/sandboxedsdktoolbox/testdata";

  @Test
  public void generateManifest_forSingleSdkModuleConfig_success() throws Exception {
    String manifestPackage = "com.example.generatedmanifest";
    File sdkConfigFile = testDataFile("com.example.firstsdkconfig.json");
    File outputFile = testFolder.newFile();

    CommandResult result =
        runCommand(
            "generate-sdk-dependencies-manifest",
            "--manifest-package",
            manifestPackage,
            "--sdk-module-configs",
            sdkConfigFile.getPath(),
            "--debug-keystore",
            getDebugKeystorePath(),
            "--debug-keystore-pass",
            "android",
            "--debug-keystore-alias",
            "androiddebugkey",
            "--output-manifest",
            outputFile.getPath());

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
    assertThat(readFromFile(outputFile))
        .isEqualTo(readFromFile(testDataFile("expected_manifest_single_sdk.xml")));
  }

  @Test
  public void generateManifest_forMultipleSdkModuleConfigs_success() throws Exception {
    String manifestPackage = "com.example.generatedmanifest";
    File firstSdkConfigFile = testDataFile("com.example.firstsdkconfig.json");
    File secondSdkConfigFile = testDataFile("com.example.secondsdkconfig.json");
    String configPaths =
        String.format("%s,%s", firstSdkConfigFile.getPath(), secondSdkConfigFile.getPath());
    File outputFile = testFolder.newFile();

    CommandResult result =
        runCommand(
            "generate-sdk-dependencies-manifest",
            "--manifest-package",
            manifestPackage,
            "--sdk-module-configs",
            configPaths,
            "--debug-keystore",
            getDebugKeystorePath(),
            "--debug-keystore-pass",
            "android",
            "--debug-keystore-alias",
            "androiddebugkey",
            "--output-manifest",
            outputFile.getPath());

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
    assertThat(readFromFile(outputFile))
        .isEqualTo(readFromFile(testDataFile("expected_manifest_multiple_sdks.xml")));
  }

  private static final class CommandResult {
    private final int statusCode;
    private final String output;

    int getStatusCode() {
      return statusCode;
    }

    String getOutput() {
      return output;
    }

    CommandResult(int statusCode, String output) {
      this.statusCode = statusCode;
      this.output = output;
    }
  }

  private static CommandResult runCommand(String... parameters) {
    CommandLine command = SandboxedSdkToolbox.create();
    StringWriter stringWriter = new StringWriter();

    command.setOut(new PrintWriter(stringWriter));
    int statusCode = command.execute(parameters);
    String output = stringWriter.toString();

    return new CommandResult(statusCode, output);
  }

  private static String getDebugKeystorePath() {
    /*
     The test key was generated with this command, its password is "android"
     keytool -genkeypair \
       -alias androiddebugkey \
       -dname "CN=Android Debug, O=Android, C=US" \
       -keystore test_key \
       -sigalg SHA256withDSA \
       -validity 10950
    */
    return testDataFile("test_key").getPath();
  }

  private static File testDataFile(String path) {
    return Paths.get(System.getenv("TEST_SRCDIR"), TEST_DATA_DIR, path).toFile();
  }

  private static String readFromFile(File file) throws Exception {
    try (var reader = Files.newReader(file, UTF_8)) {
      return reader.lines().collect(joining("\n"));
    }
  }
}
