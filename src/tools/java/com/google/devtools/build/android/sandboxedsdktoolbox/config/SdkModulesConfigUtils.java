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
package com.google.devtools.build.android.sandboxedsdktoolbox.config;

import com.android.bundle.SdkModulesConfigOuterClass.SdkModulesConfig;
import com.android.tools.build.bundletool.model.RuntimeEnabledSdkVersionEncoder;
import com.google.protobuf.util.JsonFormat;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;

/** Utilities for creating and extracting information from {@link SdkModulesConfig} messages. */
public final class SdkModulesConfigUtils {

  public static SdkModulesConfig readFromJsonFile(Path configPath) {
    SdkModulesConfig.Builder builder = SdkModulesConfig.newBuilder();
    try {
      JsonFormat.parser().merge(Files.newBufferedReader(configPath), builder);
      return builder.build();
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to parse SDK Module Config.", e);
    }
  }

  public static long getVersionMajor(SdkModulesConfig config) {
    return RuntimeEnabledSdkVersionEncoder.encodeSdkMajorAndMinorVersion(
        config.getSdkVersion().getMajor(), config.getSdkVersion().getMinor());
  }

  private SdkModulesConfigUtils() {}
}
