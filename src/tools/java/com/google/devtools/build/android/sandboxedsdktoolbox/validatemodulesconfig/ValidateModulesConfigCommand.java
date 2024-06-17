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

import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfo;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfoReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/** Checks if the given modules config is valid and compatible with other build parameters. */
@Command(
    name = "validate-modules-config",
    description =
        "Checks if the given modules config is valid and compatible with other build"
            + " parameters.")
public final class ValidateModulesConfigCommand implements Runnable {

  @Option(names = "--sdk-modules-config", required = true)
  Path sdkModuleConfigPath;

  @Option(names = "--java-package-name", required = true)
  String javaPackageName;

  @Option(names = "--output", required = true)
  Path output;

  @Override
  public void run() {
    SdkInfo info = SdkInfoReader.readFromSdkModuleJsonFile(sdkModuleConfigPath);

    if (!info.getPackageName().equals(javaPackageName)) {
      throw new IllegalArgumentException(
          String.format(
              "The package name in the modules config (%s) does not match the java package name "
                  + "(%s). This causes runtime errors when running the SDK as a split APK.",
              info.getPackageName(), javaPackageName));
    }

    try {
      // Empty file representing a successful validation.
      Files.createFile(output);
    } catch (IOException e) {
      throw new IllegalStateException("Failed to create output file", e);
    }
  }

  private ValidateModulesConfigCommand() {}
}
