// Copyright 2026 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.google.devtools.build.android.aapt2;

import static com.google.common.truth.Truth.assertThat;

import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.common.io.MoreFiles;
import com.google.common.io.RecursiveDeleteOption;
import com.google.common.util.concurrent.ListeningExecutorService;
import com.google.common.util.concurrent.MoreExecutors;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public class ResourceLinkerTest {

  private static final Path ANDROID_JAR = Path.of("fake/android.jar");
  private static final Path AAPT2 = Path.of("fake/aapt2");
  private static final Path FAKE_MANIFEST = Path.of("fake/AndroidManifest.xml");
  // ResourceLinker creates a "filtered" directory inside its working directory when it performs
  // filtering.
  private static final String FILTERED_DIR_NAME = "filtered";
  private Path tempDir;
  private Path workingDir;
  private ListeningExecutorService executorService;

  @Before
  public void setup() throws Exception {
    tempDir = Files.createTempDirectory("ResourceLinkerTest");
    workingDir = Files.createDirectories(tempDir.resolve("working"));
    executorService = MoreExecutors.newDirectExecutorService();
  }

  @After
  public void cleanup() throws IOException {
    MoreFiles.deleteRecursively(tempDir, RecursiveDeleteOption.ALLOW_INSECURE);
  }

  private Path createFakeCompiledResourcesZip(boolean includeNonFlat) throws IOException {
    Path zipPath = tempDir.resolve("compiled_resources.zip");
    try (ZipOutputStream zos = new ZipOutputStream(new FileOutputStream(zipPath.toFile()))) {
      // Add a flat file
      ZipEntry flatEntry = new ZipEntry("values_default.flat");
      zos.putNextEntry(flatEntry);
      zos.write("fake flat content".getBytes());
      zos.closeEntry();

      if (includeNonFlat) {
        // Add a non-flat file
        ZipEntry txtEntry = new ZipEntry("dummy.txt");
        zos.putNextEntry(txtEntry);
        zos.write("fake txt content".getBytes());
        zos.closeEntry();
      }
    }
    return zipPath;
  }

  @Test
  public void testLinkStatically_withFix_noFiltering() throws Exception {
    Path zipPath = createFakeCompiledResourcesZip(true); // contains non-flat
    CompiledResources compiled = CompiledResources.from(zipPath, FAKE_MANIFEST);

    ResourceLinker linker =
        ResourceLinker.create(AAPT2, executorService, workingDir)
            .aapt2CompatFlags(ImmutableMap.of("aapt2_skip_flat_files_fix", "true"))
            .dependencies(ImmutableList.of(StaticLibrary.from(ANDROID_JAR)));

    List<String> paths = linker.compiledResourcesToPaths(compiled, ResourceLinker.ALWAYS_TRUE);

    assertThat(paths).containsExactly(zipPath.toString());

    Path filteredDir = workingDir.resolve(FILTERED_DIR_NAME);
    assertThat(Files.exists(filteredDir)).isFalse();
  }

  @Test
  public void testLinkStatically_noFix_doesFiltering() throws Exception {
    Path zipPath = createFakeCompiledResourcesZip(true); // contains non-flat
    CompiledResources compiled = CompiledResources.from(zipPath, FAKE_MANIFEST);

    ResourceLinker linker =
        ResourceLinker.create(AAPT2, executorService, workingDir)
            .aapt2CompatFlags(ImmutableMap.of("aapt2_skip_flat_files_fix", "false"))
            .dependencies(ImmutableList.of(StaticLibrary.from(ANDROID_JAR)));

    List<String> paths = linker.compiledResourcesToPaths(compiled, ResourceLinker.ALWAYS_TRUE);

    Path filteredDir = workingDir.resolve(FILTERED_DIR_NAME);
    assertThat(Files.exists(filteredDir)).isTrue();

    Path expectedFilteredZip =
        filteredDir.resolve(
            zipPath.isAbsolute() ? zipPath.subpath(1, zipPath.getNameCount()) : zipPath);

    assertThat(Files.exists(expectedFilteredZip)).isTrue();
    assertThat(paths).containsExactly(expectedFilteredZip.toString());
  }
}
