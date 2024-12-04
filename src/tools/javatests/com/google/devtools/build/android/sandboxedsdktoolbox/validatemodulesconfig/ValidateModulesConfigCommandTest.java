/*
 * Copyright 2024 The Bazel Authors. All rights reserved.
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
package com.google.devtools.build.android.sandboxedsdktoolbox.validatemodulesconfig;

import static com.google.common.truth.Truth.assertThat;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Runner.runCommand;

import com.android.bundle.SdkModulesConfigOuterClass.SdkModulesConfig;
import com.google.devtools.build.android.sandboxedsdktoolbox.utils.CommandResult;
import com.google.protobuf.util.JsonFormat;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class ValidateModulesConfigCommandTest {

  @Rule public final TemporaryFolder testFolder = new TemporaryFolder();

  @Test
  public void modulesConfig_withTheSameJavaPackage_succeeds() throws Exception {
    SdkModulesConfig config =
        SdkModulesConfig.newBuilder().setSdkPackageName("com.example.package").build();
    String javaPackageName = "com.example.package";
    Path output = testFolder.getRoot().toPath().resolve("output");

    CommandResult result = runValidateCommand(config, javaPackageName, output);

    assertThat(result.getOutput()).isEmpty();
    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(Files.exists(output)).isTrue();
  }

  @Test
  public void modulesConfig_withMismatchedJavaPackage_failsValidation() throws Exception {
    SdkModulesConfig config =
        SdkModulesConfig.newBuilder().setSdkPackageName("com.example.package").build();
    String javaPackageName = "com.example.package.different";
    Path output = testFolder.getRoot().toPath().resolve("output");

    CommandResult result = runValidateCommand(config, javaPackageName, output);

    assertThat(result.getOutput())
        .contains(
            "The package name in the modules config (com.example.package) does not match the java"
                + " package name (com.example.package.different)");
    assertThat(result.getStatusCode()).isEqualTo(1);
    assertThat(Files.exists(output)).isFalse();
  }

  private CommandResult runValidateCommand(
      SdkModulesConfig config, String javaPackageName, Path output) throws Exception {
    Path sdkModulesConfigPath = testFolder.getRoot().toPath().resolve("sdk-modules-config.pb.json");
    Files.writeString(sdkModulesConfigPath, JsonFormat.printer().print(config));
    return runCommand(
        "validate-modules-config",
        "--sdk-modules-config",
        sdkModulesConfigPath.toString(),
        "--java-package-name",
        javaPackageName,
        "--output",
        output.toString());
  }
}
