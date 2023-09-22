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
package com.google.devtools.build.android.sandboxedsdktoolbox.info;

import com.android.bundle.SdkMetadataOuterClass.SdkMetadata;
import com.android.bundle.SdkModulesConfigOuterClass.RuntimeEnabledSdkVersion;
import com.android.bundle.SdkModulesConfigOuterClass.SdkModulesConfig;
import com.android.tools.build.bundletool.model.RuntimeEnabledSdkVersionEncoder;
import com.google.protobuf.ExtensionRegistry;
import com.google.protobuf.util.JsonFormat;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;

/** Reads SDK information SDK archives and Bundle metadata files. */
public final class SdkInfoReader {

  // SDK metadata proto sits at the top level of an ASAR.
  private static final String SDK_METADATA_ENTRY_PATH = "SdkMetadata.pb";

  public static SdkInfo readFromSdkModuleJsonFile(Path sdkModulesConfigPath) {
    SdkModulesConfig.Builder modulesConfig = SdkModulesConfig.newBuilder();
    try {
      JsonFormat.parser().merge(Files.newBufferedReader(sdkModulesConfigPath), modulesConfig);
      return new SdkInfo(
          modulesConfig.getSdkPackageName(), getVersionMajor(modulesConfig.getSdkVersion()));
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to parse SDK Module Config.", e);
    }
  }

  public static SdkInfo readFromSdkArchive(Path sdkArchivePath) {
    URI uri = URI.create("jar:" + sdkArchivePath.toUri());
    try (FileSystem zipfs = FileSystems.newFileSystem(uri, new HashMap<String, String>())) {
      Path metadataInAsar = zipfs.getPath(SDK_METADATA_ENTRY_PATH);
      if (!Files.exists(metadataInAsar)) {
        throw new IllegalStateException(
            String.format("Could not find %s in %s", SDK_METADATA_ENTRY_PATH, sdkArchivePath));
      }
      SdkMetadata metadata =
          SdkMetadata.parseFrom(
              Files.readAllBytes(metadataInAsar), ExtensionRegistry.getEmptyRegistry());
      return new SdkInfo(metadata.getPackageName(), getVersionMajor(metadata.getSdkVersion()));
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to extract SDK API descriptors.", e);
    }
  }

  private static long getVersionMajor(RuntimeEnabledSdkVersion version) {
    return RuntimeEnabledSdkVersionEncoder.encodeSdkMajorAndMinorVersion(
        version.getMajor(), version.getMinor());
  }

  private SdkInfoReader() {}
}
