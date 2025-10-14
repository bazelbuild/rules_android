// Copyright 2017 The Bazel Authors. All rights reserved.
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
package com.google.devtools.build.android;

import static com.google.common.truth.Truth.assertThat;

import com.google.common.jimfs.Jimfs;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.zip.CRC32;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

/** Tests for {@link AndroidResourceOutputsTest}. */
@RunWith(JUnit4.class)
public class AndroidResourceOutputsTest {
  private Path tmp;

  @Before
  public void setUp() throws Exception {
    tmp =
        Files.createTempDirectory(
            Jimfs.newFileSystem().getRootDirectories().iterator().next(),
            getClass().getSimpleName());
  }

  @Test
  public void testZipEntryPaths() throws Exception {
    Path output = tmp.resolve("actual.zip");
    Files.createDirectories(tmp.resolve("foo/bar"));
    Files.write(tmp.resolve("foo/data1.txt"), "hello".getBytes(Charset.defaultCharset()));
    Files.write(tmp.resolve("foo/bar/data2.txt"), "world".getBytes(Charset.defaultCharset()));

    try (ZipOutputStream zout = new ZipOutputStream(Files.newOutputStream(output))) {
      AndroidResourceOutputs.ZipBuilderVisitor visitor =
          new AndroidResourceOutputs.ZipBuilderVisitor(
              AndroidResourceOutputs.ZipBuilder.wrap(zout), tmp.resolve("foo"), "some/prefix");
      Files.walkFileTree(tmp.resolve("foo"), visitor);
      visitor.writeEntries();
    }

    List<String> entries = new ArrayList<>();
    try (ZipInputStream zin = new ZipInputStream(Files.newInputStream(output))) {
      ZipEntry entry = null;
      while ((entry = zin.getNextEntry()) != null) {
        entries.add(entry.getName());
      }
    }
    assertThat(entries).containsExactly("some/prefix/data1.txt", "some/prefix/bar/data2.txt");
  }

  @Test
  public void zipBuilder_addEntry_contentFactory() throws Exception {
    Path output = tmp.resolve("actual.zip");
    Path fileToAdd = tmp.resolve("foo/data1.txt");
    Files.createDirectories(fileToAdd.getParent());
    byte[] content = "hello world".getBytes(Charset.defaultCharset());
    Files.write(fileToAdd, content);

    try (ZipOutputStream zout = new ZipOutputStream(Files.newOutputStream(output))) {
      AndroidResourceOutputs.ZipBuilder zipBuilder = AndroidResourceOutputs.ZipBuilder.wrap(zout);
      zipBuilder.addEntry(
          "a/prefix/data1.txt",
          () -> Files.newInputStream(fileToAdd),
          ZipEntry.STORED,
          /* comment= */ null);
    }

    try (ZipInputStream zin = new ZipInputStream(Files.newInputStream(output))) {
      ZipEntry entry = zin.getNextEntry();
      assertThat(entry).isNotNull();
      assertThat(entry.getName()).isEqualTo("a/prefix/data1.txt");
      assertThat(entry.getMethod()).isEqualTo(ZipEntry.STORED);
      byte[] zippedContent = zin.readAllBytes();
      assertThat(zippedContent).isEqualTo(content);
      CRC32 crc32 = new CRC32();
      crc32.update(content);
      assertThat(entry.getCrc()).isEqualTo(crc32.getValue());
      assertThat(entry.getSize()).isEqualTo(content.length);
      assertThat(zin.getNextEntry()).isNull();
    }
  }
}
