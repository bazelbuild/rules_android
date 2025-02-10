/*
 * Copyright 2025 The Bazel Authors. All rights reserved.
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
package com.google.devtools.build.android.sandboxedsdktoolbox.proguardspecs;

import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfo;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfoReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import picocli.CommandLine.Command;
import picocli.CommandLine.Option;

/** Generates a proguard specs file for a sandboxed SDK. */
@Command(
    name = "generate-sdk-proguard-specs",
    description = "Generates a proguard specs file for a sandboxed SDK.")
public final class GenerateSdkProguardSpecsCommand implements Runnable {

  @Option(names = "--sdk-modules-config", required = true)
  Path sdkModuleConfigPath;

  @Option(names = "--output", required = true)
  Path output;

  @Override
  public void run() {
    SdkInfo info = SdkInfoReader.readFromSdkModuleJsonFile(sdkModuleConfigPath);

    List<String> rules = new ArrayList<>();
    rules.add("# Generated by the generate-sdk-proguard-specs command.");
    addShimRules(rules);

    info.getSdkProviderClassName().ifPresent(className -> rules.add(keepClassRule(className)));
    info.getCompatSdkProviderClassName()
        .ifPresent(className -> rules.add(keepClassRule(className)));
    rules.add(keepClassRule(info.getPackageName() + ".RPackage"));

    try {
      Files.write(output, rules);
    } catch (IOException e) {
      throw new IllegalStateException("Failed to create output file", e);
    }
  }

  private void addShimRules(List<String> rules) {
    addKeepShimRule(rules, "androidx.privacysandbox.tools.PrivacySandboxValue");
    addKeepShimRule(rules, "androidx.privacysandbox.tools.PrivacySandboxInterface");
    addKeepShimRule(rules, "androidx.privacysandbox.tools.PrivacySandboxService");
    addKeepShimRule(rules, "androidx.privacysandbox.tools.PrivacySandboxCallback");
  }

  private void addKeepShimRule(List<String> rules, String className) {
    rules.add(keepShimClassRule(className));
    rules.add(keepShimInterfaceRule(className));
  }

  private String keepClassRule(String className) {
    return "-keep class " + className + " { *; }";
  }

  private String keepShimClassRule(String className) {
    return "-keep @" + className + " class ** { *; }";
  }

  private String keepShimInterfaceRule(String className) {
    return "-keep @" + className + " interface ** { *; }";
  }

  private GenerateSdkProguardSpecsCommand() {}
}
