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
package com.google.devtools.build.android.r8;

import static com.google.common.collect.Iterables.getOnlyElement;
import static com.google.common.truth.Truth.assertThat;
import static java.nio.charset.StandardCharsets.UTF_8;

import com.android.tools.r8.ArchiveClassFileProvider;
import com.android.tools.r8.ClassFileResourceProvider;
import com.android.tools.r8.ProgramResource;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.devtools.build.android.r8.desugar.LazyArchiveClassFileProvider;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

/** Tests for {@link LazyArchiveClassFileProvider}. */
@RunWith(JUnit4.class)
public class LazyArchiveClassFileProviderTest {
  @Rule public final TemporaryFolder temp = new TemporaryFolder();

  private static final ImmutableList<String> ENTRIES =
      ImmutableList.of(
          "a/",
          "a/A.class",
          "a/A$Inner.class",
          "b/B.class",
          "module-info.class",
          "META-INF/MANIFEST.MF",
          "META-INF/versions/9/a/A.class",
          "a/resource.txt");

  @Test
  public void plainArchive() throws Exception {
    Path archive = writeArchive(ENTRIES);
    assertSameAsArchiveClassFileProvider(archive);
    // Entries that ArchiveClassFileProvider doesn't index are not provided either.
    LazyArchiveClassFileProvider provider = new LazyArchiveClassFileProvider(archive);
    assertThat(provider.getProgramResource("Lmodule-info;")).isNull();
    assertThat(provider.getProgramResource("LMETA-INF/versions/9/a/A;")).isNull();
  }

  @Test
  public void emptyArchive() throws Exception {
    assertSameAsArchiveClassFileProvider(writeArchive(ImmutableList.of()));
  }

  @Test
  public void readAfterFinished() throws Exception {
    LazyArchiveClassFileProvider provider = new LazyArchiveClassFileProvider(writeArchive(ENTRIES));
    assertThat(provider.getProgramResource("La/A;")).isNotNull();
    provider.finished(null);
    provider.finished(null);
    assertThat(provider.getProgramResource("La/A;").getBytes())
        .isEqualTo("a/A.class".repeat(100).getBytes(UTF_8));
  }

  private Path writeArchive(List<String> entries) throws IOException {
    Path archive = Files.createTempFile(temp.getRoot().toPath(), "archive", ".jar");
    try (OutputStream out = Files.newOutputStream(archive);
        ZipOutputStream zip = new ZipOutputStream(out, UTF_8)) {
      for (String entry : entries) {
        zip.putNextEntry(new ZipEntry(entry));
        zip.write(entry.repeat(100).getBytes(UTF_8));
        zip.closeEntry();
      }
    }
    return archive;
  }

  private static void assertSameAsArchiveClassFileProvider(Path archive) throws Exception {
    LazyArchiveClassFileProvider provider = new LazyArchiveClassFileProvider(archive);
    try (ArchiveClassFileProvider expected = new ArchiveClassFileProvider(archive)) {
      assertThat(provider.getClassDescriptors())
          .containsExactlyElementsIn(expected.getClassDescriptors());
      for (String descriptor : expected.getClassDescriptors()) {
        ProgramResource resource = provider.getProgramResource(descriptor);
        ProgramResource expectedResource = expected.getProgramResource(descriptor);
        assertThat(resource.getBytes()).isEqualTo(expectedResource.getBytes());
        assertThat(resource.getOrigin()).isEqualTo(expectedResource.getOrigin());
        assertThat(resource.getKind()).isEqualTo(expectedResource.getKind());
        assertThat(resource.getClassDescriptors())
            .isEqualTo(expectedResource.getClassDescriptors());
      }
      assertThat(getAllProgramResources(provider))
          .containsExactlyEntriesIn(getAllProgramResources(expected));
    }
    assertThat(provider.getProgramResource("LMissing;")).isNull();
  }

  /** Returns the contents of the resources from getProgramResources by descriptor. */
  private static ImmutableMap<String, String> getAllProgramResources(
      ClassFileResourceProvider provider) throws Exception {
    List<ProgramResource> resources = new ArrayList<>();
    provider.getProgramResources(resources::add);
    ImmutableMap.Builder<String, String> contents = ImmutableMap.builder();
    for (ProgramResource resource : resources) {
      contents.put(
          getOnlyElement(resource.getClassDescriptors()), new String(resource.getBytes(), UTF_8));
    }
    return contents.buildOrThrow();
  }
}
