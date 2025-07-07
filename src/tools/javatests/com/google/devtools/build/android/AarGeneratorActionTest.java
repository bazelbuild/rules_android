// Copyright 2018 The Bazel Authors. All rights reserved.
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
import static java.nio.charset.StandardCharsets.UTF_8;
import static org.hamcrest.CoreMatchers.containsString;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertThrows;

import com.android.builder.core.VariantTypeImpl;
import com.beust.jcommander.JCommander;
import com.beust.jcommander.ParameterException;
import com.google.common.base.Joiner;
import com.google.common.collect.ImmutableList;
import com.google.devtools.build.android.AarGeneratorAction.AarGeneratorOptions;
import com.google.errorprone.annotations.CanIgnoreReturnValue;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.ExpectedException;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

/** Tests for {@link AarGeneratorAction}. */
@RunWith(JUnit4.class)
public class AarGeneratorActionTest {

  private static class AarData {
    /** Templates for resource files generation. */
    enum ResourceType {
      VALUE {
        @Override public String create(String... lines) {
          return String.format(
              "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>%s</resources>",
              Joiner.on("\n").join(lines));
        }
      },
      LAYOUT {
        @Override public String create(String... lines) {
          return String.format("<?xml version=\"1.0\" encoding=\"utf-8\"?>"
              + "<LinearLayout xmlns:android=\"http://schemas.android.com/apk/res/android\""
              + " android:layout_width=\"fill_parent\""
              + " android:layout_height=\"fill_parent\">%s</LinearLayout>",
              Joiner.on("\n").join(lines));
        }
      },
      UNFORMATTED {
        @Override public String create(String... lines) {
          return String.format(Joiner.on("\n").join(lines));
        }
      };

      public abstract String create(String... lines);
    }

    private static class Builder {

      private final Path root;
      private final Path assetDir;
      private final Path resourceDir;
      private Path manifest;
      private Path aarMetadata;
      private Path rtxt;
      private Path classes;
      private Map<Path, String> filesToWrite = new HashMap<>();
      private Map<String, String> classesToWrite = new HashMap<>();
      private ImmutableList.Builder<Path> proguardSpecs = ImmutableList.builder();
      private boolean withEmptyRes = false;
      private boolean withEmptyAssets = false;

      public Builder(Path root) {
        this(root, "res", "assets");
      }

      public Builder(Path root, String resourceRoot, String assetRoot) {
        this.root = root;
        assetDir = root.resolve(assetRoot);
        resourceDir = root.resolve(resourceRoot);
        manifest = root.resolve("fake-manifest-path");
        rtxt = root.resolve("fake-rtxt-path");
        classes = root.resolve("fake-classes-path");
        aarMetadata = root.resolve("fake-aar-metadata-path");
      }

      @CanIgnoreReturnValue
      public Builder addResource(String path, ResourceType template, String... lines) {
        filesToWrite.put(resourceDir.resolve(path), template.create(lines));
        return this;
      }

      @CanIgnoreReturnValue
      public Builder withEmptyResources(boolean isEmpty) {
        this.withEmptyRes = isEmpty;
        return this;
      }

      @CanIgnoreReturnValue
      public Builder addAsset(String path, String... lines) {
        filesToWrite.put(assetDir.resolve(path), Joiner.on("\n").join(lines));
        return this;
      }

      @CanIgnoreReturnValue
      public Builder withEmptyAssets(boolean isEmpty) {
        this.withEmptyAssets = isEmpty;
        return this;
      }

      @CanIgnoreReturnValue
      public Builder createManifest(String path, String manifestPackage, String... lines) {
        this.manifest = root.resolve(path);
        filesToWrite.put(manifest, String.format("<?xml version=\"1.0\" encoding=\"utf-8\"?>"
            + "<manifest xmlns:android='http://schemas.android.com/apk/res/android' package='%s'>"
            + "%s</manifest>", manifestPackage, Joiner.on("\n").join(lines)));
        return this;
      }

      @CanIgnoreReturnValue
      public Builder addNullAarMetadata() {
        this.aarMetadata = null;
        return this;
      }

      @CanIgnoreReturnValue
      public Builder addNonExistentAarMetadata() {
        this.aarMetadata = root.resolve("/nonexistent/aar-metadata.properties");
        return this;
      }

      @CanIgnoreReturnValue
      public Builder addAarMetadata(String path) {
        this.aarMetadata = root.resolve(path);
        filesToWrite.put(
            aarMetadata,
            """
            aarFormatVersion=1.0
            aarMetadataVersion=1.0
            minCompileSdk=1
            minCompileSdkExtension=0
            minAndroidGradlePluginVersion=8.2.0
            coreLibraryDesugaringEnabled=true
            desugarJdkLib=com.android.tools:desugar_jdk_libs:2.1.3\
            """);
        return this;
      }

      @CanIgnoreReturnValue
      public Builder createRtxt(String path, String... lines) {
        this.rtxt = root.resolve(path);
        filesToWrite.put(rtxt, String.format("%s", Joiner.on("\n").join(lines)));
        return this;
      }

      @CanIgnoreReturnValue
      public Builder createClassesJar(String path) {
        this.classes = root.resolve(path);
        classesToWrite.put("META-INF/MANIFEST.MF", "Manifest-Version: 1.0\n");
        return this;
      }

      @CanIgnoreReturnValue
      public Builder addClassesFile(String filePackage, String filename, String... lines) {
        classesToWrite.put(filePackage.replace(".", "/") + "/" + filename,
            String.format("%s", Joiner.on("\n").join(lines)));
        return this;
      }

      @CanIgnoreReturnValue
      public Builder addProguardSpec(String path, String... lines) {
        Path proguardSpecPath = root.resolve(path);
        proguardSpecs.add(proguardSpecPath);
        filesToWrite.put(proguardSpecPath, String.format("%s", Joiner.on("\n").join(lines)));
        return this;
      }

      public AarData build() throws IOException {
        writeFiles();
        return new AarData(
            buildMerged(), manifest, rtxt, classes, aarMetadata, proguardSpecs.build());
      }

      private MergedAndroidData buildMerged() {
        return new MergedAndroidData(
            resourceDir,
            assetDir,
            manifest);
      }

      private void writeFiles() throws IOException {
        assertNotNull("A manifest is required.", manifest);
        assertNotNull("A resource file is required.", rtxt);
        assertNotNull("A classes jar is required.", classes);
        if (withEmptyRes) {
          Files.createDirectories(resourceDir);
        }
        if (withEmptyAssets) {
          Files.createDirectories(assetDir);
        }
        for (Map.Entry<Path, String> entry : filesToWrite.entrySet()) {
          Path file = entry.getKey();
          // only write files in assets if assets has not been set to empty and same for resources
          if (!((file.startsWith(assetDir) && withEmptyAssets)
              || (file.startsWith(resourceDir) && withEmptyRes))) {
            Files.createDirectories(file.getParent());
            Files.write(file, entry.getValue().getBytes(StandardCharsets.UTF_8));
            assertThat(Files.exists(file)).isTrue();
          }
        }
        if (!classesToWrite.isEmpty()) {
          writeClassesJar();
        }
      }

      private void writeClassesJar() throws IOException {
        final ZipOutputStream zout = new ZipOutputStream(new FileOutputStream(classes.toFile()));

        for (Map.Entry<String, String> file : classesToWrite.entrySet()) {
          ZipEntry entry = new ZipEntry(file.getKey());
          zout.putNextEntry(entry);
          zout.write(file.getValue().getBytes(UTF_8));
          zout.closeEntry();
        }

        zout.close();

        Files.setLastModifiedTime(classes, FileTime.from(AarGeneratorAction.DEFAULT_TIMESTAMP));
      }
    }

    final MergedAndroidData data;
    final Path manifest;
    final Path rtxt;
    final Path classes;
    final Path aarMetadata;
    final ImmutableList<Path> proguardSpecs;

    private AarData(
        MergedAndroidData data,
        Path manifest,
        Path rtxt,
        Path classes,
        Path aarMetadata,
        ImmutableList<Path> proguardSpecs) {
      this.data = data;
      this.manifest = manifest;
      this.rtxt = rtxt;
      this.classes = classes;
      this.aarMetadata = aarMetadata;
      this.proguardSpecs = proguardSpecs;
    }
  }

  /**
   * Operation to perform on a file.
   */
  private interface FileOperation {
    /**
     * Performs the operation on a file, given its name, modificationTime and contents.
     */
    void perform(String name, long modificationTime, String contents);
  }

  /**
   * Runs a {@link FileOperation} on every entry in a zip file.
   *
   * @param zip {@link Path} of the zip file to traverse.
   * @param operation {@link FileOperation} to be run on every entry of the zip file.
   * @throws IOException if there is an error reading the zip file.
   */
  private void traverseZipFile(Path zip, FileOperation operation) throws IOException {
    ZipInputStream zis = new ZipInputStream(Files.newInputStream(zip));
    ZipEntry z = zis.getNextEntry();
    while (z != null) {
      ByteArrayOutputStream baos = new ByteArrayOutputStream();
      byte[] buffer = new byte[1024];
      for (int count = 0; count != -1; count = zis.read(buffer)) {
        baos.write(buffer);
      }
      // Replace Windows path separators so that test cases are consistent across platforms.
      String name = z.getName().replace('\\', '/');
      operation.perform(
          name, z.getTime(), new String(baos.toByteArray(), StandardCharsets.UTF_8));
      z = zis.getNextEntry();
    }
  }

  private Set<String> getZipEntries(Path zip) throws IOException {
    final Set<String> zipEntries = new HashSet<>();
    traverseZipFile(zip, new FileOperation() {
      @Override public void perform(String name, long modificationTime, String contents) {
        zipEntries.add(name);
      }
    });
    return zipEntries;
  }

  private Set<Long> getZipEntryTimestamps(Path zip) throws IOException {
    final Set<Long> timestamps = new HashSet<>();
    traverseZipFile(zip, new FileOperation() {
      @Override public void perform(String name, long modificationTime, String contents) {
        timestamps.add(modificationTime);
      }
    });
    return timestamps;
  }

  private Path tempDir;

  @Rule public ExpectedException thrown = ExpectedException.none();

  @Before public void setUp() throws IOException {
    tempDir = Files.createTempDirectory(toString());
    tempDir.toFile().deleteOnExit();

  }

  private AarGeneratorOptions parseFlags(String[] args) throws ParameterException {
    AarGeneratorOptions options = new AarGeneratorOptions();
    JCommander jc = new JCommander(options);
    String[] preprocessedArgs = AndroidOptionsUtils.runArgFilePreprocessor(jc, args);
    String[] normalizedArgs =
        AndroidOptionsUtils.normalizeBooleanOptions(options, preprocessedArgs);
    jc.parse(normalizedArgs);
    return options;
  }

  @Test
  public void testCheckFlags() throws IOException, ParameterException {
    Path manifest = tempDir.resolve("AndroidManifest.xml");
    Files.createFile(manifest);
    Path rtxt = tempDir.resolve("R.txt");
    Files.createFile(rtxt);
    Path classes = tempDir.resolve("classes.jar");
    Files.createFile(classes);

    String[] args = new String[] {"--manifest", manifest.toString(), "--rtxt", rtxt.toString(),
        "--classes", classes.toString()};
    AarGeneratorOptions options = parseFlags(args);
    AarGeneratorAction.checkFlags(options);
  }

  @Test
  public void testCheckFlags_MissingClasses() throws IOException, ParameterException {
    Path manifest = tempDir.resolve("AndroidManifest.xml");
    Files.createFile(manifest);
    Path rtxt = tempDir.resolve("R.txt");
    Files.createFile(rtxt);

    String[] args = new String[] {"--manifest", manifest.toString(), "--rtxt", rtxt.toString()};
    AarGeneratorOptions options = parseFlags(args);
    thrown.expect(IllegalArgumentException.class);
    thrown.expectMessage("classes must be specified. Building an .aar without"
          + " classes is unsupported.");
    AarGeneratorAction.checkFlags(options);
  }

  @Test
  public void testCheckFlags_MissingMultiple() throws IOException, ParameterException {
    Path manifest = tempDir.resolve("AndroidManifest.xml");
    Files.createFile(manifest);
    String[] args = new String[] {"--manifest", manifest.toString()};
    AarGeneratorOptions options = parseFlags(args);
    thrown.expect(IllegalArgumentException.class);
    thrown.expectMessage("rtxt, classes must be specified. Building an .aar without"
          + " rtxt, classes is unsupported.");
    AarGeneratorAction.checkFlags(options);
  }

  @Test
  public void testWriteAar() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addAarMetadata("foo.properties")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);
  }

  @Test
  public void testNullAarMetadata() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addNullAarMetadata()
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);

    assertThat(getZipEntries(aar))
        .doesNotContain("META-INF/com/android/build/gradle/aar-metadata.properties");
  }

  @Test
  public void testNonexistentAarMetadataPath() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addNonExistentAarMetadata()
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    ParameterException thrown =
        assertThrows(
            ParameterException.class,
            () ->
                AarGeneratorAction.writeAar(
                    aar,
                    aarData.data,
                    aarData.manifest,
                    aarData.rtxt,
                    aarData.classes,
                    aarData.aarMetadata,
                    aarData.proguardSpecs));

    assertThat(thrown).hasMessageThat().contains("/nonexistent/aar-metadata.properties");
  }

  @Test
  public void testExistentAarMetadataPath() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addAarMetadata("foo.properties")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);

    assertThat(getZipEntries(aar))
        .contains("META-INF/com/android/build/gradle/aar-metadata.properties");
    String aarMetadataContents = "";
    try (ZipFile aarReader = new ZipFile(aar.toFile());
        BufferedReader entryReader =
            new BufferedReader(
                new InputStreamReader(
                    aarReader.getInputStream(
                        aarReader.getEntry(
                            "META-INF/com/android/build/gradle/aar-metadata.properties")),
                    StandardCharsets.UTF_8))) {
      for (String line = entryReader.readLine(); line != null; line = entryReader.readLine()) {
        aarMetadataContents += line + "\n";
      }
    }
    assertThat(aarMetadataContents).contains("aarFormatVersion=1.0");
    assertThat(aarMetadataContents).contains("aarMetadataVersion=1.0");
    assertThat(aarMetadataContents).contains("minCompileSdk=1");
    assertThat(aarMetadataContents).contains("minCompileSdkExtension=0");
    assertThat(aarMetadataContents).contains("minAndroidGradlePluginVersion=8.2.0");
    assertThat(aarMetadataContents).contains("coreLibraryDesugaringEnabled=true");
    assertThat(aarMetadataContents)
        .contains("desugarJdkLib=com.android.tools:desugar_jdk_libs:2.1.3");
  }

  @Test public void testWriteAar_DefaultTimestamps() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addAarMetadata("aar-metadata.properties")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);

    assertThat(getZipEntryTimestamps(aar))
        .containsExactly(AarGeneratorAction.DEFAULT_TIMESTAMP.toEpochMilli());
    assertThat(Files.getLastModifiedTime(aar).toInstant())
        .isEqualTo(AarGeneratorAction.DEFAULT_TIMESTAMP);
  }

  @Test public void testAssetResourceSubdirs() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"), "xyz", "assets")
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addAarMetadata("aar-metadata.properties")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);

    // verify aar archive
    Set<String> zipEntries = getZipEntries(aar);
    assertThat(zipEntries).contains("res/");
    assertThat(zipEntries).contains("assets/");
  }

  @Test public void testMissingManifest() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addAarMetadata("aar-metadata.properties")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    thrown.expect(IOException.class);
    thrown.expectMessage(containsString("fake-manifest-path"));
    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);
  }

  @Test public void testMissingRtxt() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .addAarMetadata("aar-metadata.properties")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    thrown.expect(IOException.class);
    thrown.expectMessage(containsString("fake-rtxt-path"));
    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);
  }

  @Test public void testMissingClasses() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .addAarMetadata("aar-metadata.properties")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .build();

    thrown.expect(IOException.class);
    thrown.expectMessage(containsString("fake-classes-path"));
    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);
  }

  @Test public void testMissingResources() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .addAarMetadata("aar-metadata.properties")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    thrown.expect(IOException.class);
    thrown.expectMessage(containsString("res"));
    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);
  }

  @Test public void testEmptyResources() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .addAarMetadata("aar-metadata.properties")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .withEmptyResources(true)
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .addAsset("some/other/ft/data.txt", "bar")
            .createClassesJar("classes.jar")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);
  }

  @Test public void testMissingAssets() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .addAarMetadata("aar-metadata.properties")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .createClassesJar("classes.jar")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);
  }

  @Test public void testEmptyAssets() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .addAarMetadata("aar-metadata.properties")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addResource(
                "values/ids.xml",
                AarData.ResourceType.VALUE,
                "<item name=\"id_name\" type=\"id\"/>")
            .withEmptyAssets(true)
            .createClassesJar("classes.jar")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);
  }

  @Test public void testFullIntegration() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo", "")
            .createRtxt(
                "R.txt", "int string app_name 0x7f050001", "int string hello_world 0x7f050002")
            .addAarMetadata("aar-metadata.properties")
            .addResource(
                "values/ids.xml", AarData.ResourceType.VALUE, "<item name=\"id\" type=\"id\"/>")
            .addResource(
                "layout/layout.xml",
                AarData.ResourceType.LAYOUT,
                "<TextView android:id=\"@+id/text2\""
                    + " android:layout_width=\"wrap_content\""
                    + " android:layout_height=\"wrap_content\""
                    + " android:text=\"Hello, I am a TextView\" />")
            .addAsset("some/other/ft/data.txt", "foo")
            .createClassesJar("classes.jar")
            .addClassesFile("com.google.android.apps.foo", "Test.class", "test file contents")
            .build();

    MergedAndroidData md1 = new AarData.Builder(tempDir.resolve("d1"))
        .addResource("values/ids.xml",
            AarData.ResourceType.VALUE,
            "<item name=\"id\" type=\"id\"/>")
        .addResource("layout/foo.xml",
            AarData.ResourceType.LAYOUT,
            "<TextView android:id=\"@+id/text\""
                + " android:layout_width=\"wrap_content\""
                + " android:layout_height=\"wrap_content\""
                + " android:text=\"Hello, I am a TextView\" />")
        .addAsset("some/other/ft/data1.txt",
            "bar")
        .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
        .build().data;

    MergedAndroidData md2 =
        new AarData.Builder(tempDir.resolve("d2"))
            .addResource(
                "values/ids.xml", AarData.ResourceType.VALUE, "<item name=\"id2\" type=\"id\"/>")
            .addResource(
                "layout/bar.xml",
                AarData.ResourceType.LAYOUT,
                "<TextView android:id=\"@+id/textbar\""
                    + " android:layout_width=\"wrap_content\""
                    + " android:layout_height=\"wrap_content\""
                    + " android:text=\"Hello, I am a TextView\" />")
            .addResource("drawable-mdpi/icon.png", AarData.ResourceType.UNFORMATTED, "Thttpt.")
            .addResource(
                "drawable-xxxhdpi/icon.png", AarData.ResourceType.UNFORMATTED, "Double Thttpt.")
            .addAsset("some/other/ft/data2.txt", "foo")
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d2", "")
            .addAarMetadata("aar-metadata.properties")
            .build()
            .data;

    UnvalidatedAndroidData primary = new UnvalidatedAndroidData(
        ImmutableList.of(aarData.data.getResourceDir()),
        ImmutableList.of(aarData.data.getAssetDir()),
        aarData.data.getManifest());

    DependencyAndroidData d1 =
        new DependencyAndroidData(
            ImmutableList.of(md1.getResourceDir()),
            ImmutableList.of(md1.getAssetDir()),
            md1.getManifest(),
            null,
            null,
            null);

    DependencyAndroidData d2 =
        new DependencyAndroidData(
            ImmutableList.of(md2.getResourceDir()),
            ImmutableList.of(md2.getAssetDir()),
            md2.getManifest(),
            null,
            null,
            null);

    Path working = tempDir;

    Path resourcesOut = working.resolve("resources");
    Path assetsOut = working.resolve("assets");

    MergedAndroidData mergedData =
        AndroidResourceMerger.mergeDataAndWrite(
            primary,
            ImmutableList.of(d1, d2),
            ImmutableList.<DependencyAndroidData>of(),
            resourcesOut,
            assetsOut,
            VariantTypeImpl.LIBRARY,
            null,
            /* filteredResources= */ ImmutableList.of(),
            true);

    AarGeneratorAction.writeAar(
        aar,
        mergedData,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);

    // verify aar archive
    Set<String> zipEntries = getZipEntries(aar);
    assertThat(zipEntries)
        .containsExactly(
            "AndroidManifest.xml",
            "R.txt",
            "classes.jar",
            "META-INF/com/android/build/gradle/aar-metadata.properties",
            "res/",
            "res/values/",
            "res/values/values.xml",
            "res/layout/",
            "res/layout/layout.xml",
            "res/layout/foo.xml",
            "res/layout/bar.xml",
            "res/drawable-mdpi-v4/",
            "res/drawable-mdpi-v4/icon.png",
            "res/drawable-xxxhdpi-v4/",
            "res/drawable-xxxhdpi-v4/icon.png",
            "assets/",
            "assets/some/",
            "assets/some/other/",
            "assets/some/other/ft/",
            "assets/some/other/ft/data.txt",
            "assets/some/other/ft/data1.txt",
            "assets/some/other/ft/data2.txt");
  }

  @Test public void testProguardSpecs() throws Exception {
    Path aar = tempDir.resolve("foo.aar");
    AarData aarData =
        new AarData.Builder(tempDir.resolve("data"))
            .createManifest("AndroidManifest.xml", "com.google.android.apps.foo.d1", "")
            .createRtxt("R.txt", "")
            .withEmptyResources(true)
            .withEmptyAssets(true)
            .createClassesJar("classes.jar")
            .addAarMetadata("aar-metadata.properties")
            .addProguardSpec("spec1", "foo", "bar")
            .addProguardSpec("spec2", "baz")
            .build();

    AarGeneratorAction.writeAar(
        aar,
        aarData.data,
        aarData.manifest,
        aarData.rtxt,
        aarData.classes,
        aarData.aarMetadata,
        aarData.proguardSpecs);
    Set<String> zipEntries = getZipEntries(aar);
    assertThat(zipEntries).contains("proguard.txt");
    List<String> proguardTxtContents = null;
    try (ZipFile aarReader = new ZipFile(aar.toFile())) {
      try (BufferedReader entryReader =
          new BufferedReader(
              new InputStreamReader(
                  aarReader.getInputStream(aarReader.getEntry("proguard.txt")),
                  StandardCharsets.UTF_8))) {
        proguardTxtContents = entryReader.lines().collect(Collectors.toList());
      }
    }
    assertThat(proguardTxtContents).containsExactly("foo", "bar", "baz").inOrder();
  }
}
