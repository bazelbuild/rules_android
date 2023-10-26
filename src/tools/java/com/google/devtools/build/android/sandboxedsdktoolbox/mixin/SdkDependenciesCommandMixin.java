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
package com.google.devtools.build.android.sandboxedsdktoolbox.mixin;

import static com.google.common.collect.ImmutableSet.toImmutableSet;

import com.google.common.collect.ImmutableSet;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfo;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfoReader;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;
import picocli.CommandLine.Option;

/**
 * Parses command line options that describe SDK dependencies, coming from SDK archives or bundles.
 */
public final class SdkDependenciesCommandMixin {

  private List<Path> sdkModuleConfigPaths = new ArrayList<>();
  private List<Path> sdkArchivePaths = new ArrayList<>();

  public ImmutableSet<SdkInfo> getSdkDependencies() {
    checkValid();

    return Stream.concat(
            sdkModuleConfigPaths.stream().map(SdkInfoReader::readFromSdkModuleJsonFile),
            sdkArchivePaths.stream().map(SdkInfoReader::readFromSdkArchive))
        .collect(toImmutableSet());
  }


  @Option(names = "--sdk-module-configs", split = ",", required = false)
  void setSdkModuleConfigPaths(List<Path> sdkModuleConfigPaths) {
    this.sdkModuleConfigPaths = sdkModuleConfigPaths;
  }

  @Option(names = "--sdk-archives", split = ",", required = false)
  void setSdkArchivePaths(List<Path> sdkArchivePaths) {
    this.sdkArchivePaths = sdkArchivePaths;
  }

  private void checkValid() {
    if (sdkModuleConfigPaths.isEmpty() && sdkArchivePaths.isEmpty()) {
      throw new IllegalArgumentException(
          "At least one of --sdk-module-configs or --sdk-archives must be specified.");
    }
  }

  private SdkDependenciesCommandMixin() {}
}
