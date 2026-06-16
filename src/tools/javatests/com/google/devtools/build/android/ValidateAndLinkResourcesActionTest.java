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
package com.google.devtools.build.android;

import static com.google.common.collect.ImmutableList.toImmutableList;
import static com.google.common.truth.Truth.assertThat;
import static org.junit.Assert.assertThrows;

import com.android.aapt.Resources.XmlAttribute;
import com.android.aapt.Resources.XmlElement;
import com.android.aapt.Resources.XmlNode;
import com.google.common.collect.ImmutableList;
import com.google.devtools.build.android.aapt2.CompiledResources;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Stream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public class ValidateAndLinkResourcesActionTest {

  @Rule public final TemporaryFolder tempFolder = new TemporaryFolder();

  private Path tempDir;
  private Path aapt2;
  private CompiledResources dummyCompiledResources;

  @Before
  public void setUp() throws Exception {
    tempDir = tempFolder.getRoot().toPath();
    String aapt2PathStr = System.getProperty("aapt2.path");
    assertThat(aapt2PathStr).isNotNull();
    aapt2 = Path.of(aapt2PathStr);

    Path dummyZip = tempDir.resolve("dummy.zip");

    // Create the minimal valid content for an AAPT intermediate file.
    ByteBuffer bb = ByteBuffer.allocate(12).order(ByteOrder.LITTLE_ENDIAN);
    bb.putInt(0x54504141); // AAPT_CONTAINER_MAGIC
    bb.putInt(1); // AAPT_CONTAINER_VERSION
    bb.putInt(0); // numberOfEntries
    byte[] fakeFlatData = bb.array();

    try (ZipOutputStream zos = new ZipOutputStream(new FileOutputStream(dummyZip.toFile()))) {
      zos.putNextEntry(new ZipEntry("dummy.flat"));
      zos.write(fakeFlatData);
      zos.closeEntry();
    }
    Path dummyManifest = tempDir.resolve("AndroidManifest.xml");
    Files.writeString(dummyManifest, "<manifest/>");
    dummyCompiledResources = CompiledResources.from(dummyZip, dummyManifest);
  }

  private CompiledResources createCompiledResources(
      String name, Map<String, String> files, String manifestContent) throws Exception {
    Path baseDir = tempDir.resolve(name);
    Path resDir = Files.createDirectories(baseDir.resolve("res"));
    Path outDir = Files.createDirectories(baseDir.resolve("out"));
    Path zipPath = baseDir.resolve(name + ".zip");
    Path manifestPath = baseDir.resolve("AndroidManifest.xml");

    Files.writeString(manifestPath, manifestContent);

    for (Map.Entry<String, String> entry : files.entrySet()) {
      Path xmlPath = resDir.resolve(entry.getKey());
      Files.createDirectories(xmlPath.getParent());
      Files.writeString(xmlPath, entry.getValue());

      // Run aapt2 compile
      ProcessBuilder pb =
          new ProcessBuilder(
              aapt2.toString(), "compile", "-o", outDir.toString(), xmlPath.toString());
      pb.redirectError(ProcessBuilder.Redirect.INHERIT);
      Process p = pb.start();
      int exitCode = p.waitFor();
      assertThat(exitCode).isEqualTo(0);
    }

    try (ZipOutputStream zos = new ZipOutputStream(new FileOutputStream(zipPath.toFile()));
        Stream<Path> stream = Files.list(outDir)) {
      for (Path p : stream.collect(toImmutableList())) {
        zos.putNextEntry(new ZipEntry(p.getFileName().toString()));
        Files.copy(p, zos);
        zos.closeEntry();
      }
    }

    return CompiledResources.from(zipPath, manifestPath);
  }

  @Test
  public void visibilityCheck_successNoReferences() throws Exception {
    ValidateAndLinkResourcesAction.checkVisibilityOfResourceReferences(
        XmlNode.getDefaultInstance(), dummyCompiledResources, ImmutableList.of());
  }

  @Test
  public void visibilityCheck_successNoPrivateResourcesUsed() throws Exception {
    Map<String, String> depFiles = new HashMap<>();
    depFiles.put(
        "values/public.xml",
        "<resources><public name=\"public_string\" type=\"string\"/></resources>");
    depFiles.put(
        "values/strings.xml",
        "<resources><string name=\"private_string\">hello</string></resources>");

    CompiledResources dep =
        createCompiledResources("dep", depFiles, "<manifest package=\"com.dep\"/>");

    XmlNode manifestWithRef =
        XmlNode.newBuilder()
            .setElement(
                XmlElement.newBuilder()
                    .addAttribute(
                        XmlAttribute.newBuilder()
                            .setName("hello")
                            .setValue("@string/public_string")
                            .build())
                    .build())
            .build();

    Map<String, String> libFiles = new HashMap<>();
    libFiles.put(
        "values/values.xml",
        "<resources><string name=\"lib_string\">@string/public_string</string></resources>");

    CompiledResources lib =
        createCompiledResources("lib", libFiles, "<manifest package=\"com.lib\"/>");

    ValidateAndLinkResourcesAction.checkVisibilityOfResourceReferences(
        manifestWithRef, lib, ImmutableList.of(dep));
  }

  @Test
  public void visibilityCheck_failureManifestUsesPrivateResource() throws Exception {
    Map<String, String> depFiles = new HashMap<>();
    depFiles.put(
        "values/public.xml",
        "<resources><public name=\"public_string\" type=\"string\"/></resources>");
    depFiles.put(
        "values/strings.xml",
        "<resources><string name=\"private_string\">hello</string></resources>");

    CompiledResources dep =
        createCompiledResources("dep", depFiles, "<manifest package=\"com.dep\"/>");

    XmlNode manifestWithRef =
        XmlNode.newBuilder()
            .setElement(
                XmlElement.newBuilder()
                    .addAttribute(
                        XmlAttribute.newBuilder()
                            .setName("hello")
                            .setValue("@string/private_string")
                            .build())
                    .build())
            .build();

    UserException expected =
        assertThrows(
            UserException.class,
            () ->
                ValidateAndLinkResourcesAction.checkVisibilityOfResourceReferences(
                    manifestWithRef, dummyCompiledResources, ImmutableList.of(dep)));

    assertThat(expected)
        .hasMessageThat()
        .contains(
            "AndroidManifest.xml references external private resources [string/private_string]");
  }

  @Test
  public void visibilityCheck_failureCompiledResourceValuesUsesPrivateResource() throws Exception {
    Map<String, String> depFiles = new HashMap<>();
    depFiles.put(
        "values/public.xml",
        "<resources><public name=\"public_string\" type=\"string\"/></resources>");
    depFiles.put(
        "values/strings.xml",
        "<resources><string name=\"private_string\">hello</string></resources>");

    CompiledResources dep =
        createCompiledResources("dep", depFiles, "<manifest package=\"com.dep\"/>");

    Map<String, String> libFiles = new HashMap<>();
    libFiles.put(
        "values/values.xml",
        "<resources><string name=\"lib_string\">@string/private_string</string></resources>");

    CompiledResources lib =
        createCompiledResources("lib", libFiles, "<manifest package=\"com.lib\"/>");

    UserException expected =
        assertThrows(
            UserException.class,
            () ->
                ValidateAndLinkResourcesAction.checkVisibilityOfResourceReferences(
                    XmlNode.getDefaultInstance(), lib, ImmutableList.of(dep)));

    assertThat(expected)
        .hasMessageThat()
        .contains(
            "string/lib_string (defined in "
                + tempDir.resolve("lib/res/values/values.xml")
                + ") references external private resources [string/private_string]");
  }
}
