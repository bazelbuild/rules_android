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
package com.google.devtools.build.android.dexer;

import static com.google.common.truth.Truth.assertThat;
import static com.google.common.truth.Truth.assertWithMessage;
import static java.nio.charset.StandardCharsets.UTF_8;
import static org.junit.Assert.assertThrows;

import com.google.common.base.Predicates;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableSet;
import com.google.devtools.build.android.r8.CompatDexBuilder;
import com.google.devtools.build.runfiles.Runfiles;
import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.ExecutionException;
import java.util.zip.CRC32;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;
import javax.annotation.Nullable;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

/** Tests for {@link DexFileSplitter}. */
@RunWith(JUnit4.class)
public class DexFileSplitterTest {

  private static final Path SIMPLE_JAR;
  private static final Path MULTIDEX_JAR;
  private static final Path JSIMPLE_JAR;
  private static final Path FIELDS_TYPES_JAR;

  private static final int SMALL_IDX_PER_DEX = 200; // A contrived small value for testing.
  private static final int REAL_WORLD_IDX_PER_DEX =
      256 * 256; // 65,536, typically the real world value.

  @Rule public TemporaryFolder tmp = new TemporaryFolder();

  static {
    try {
      Runfiles runfiles = Runfiles.create();

      // Look in the BUILD file for the corresponding genrules that codegen these jars.
      SIMPLE_JAR = Paths.get(runfiles.rlocation(System.getProperty("simplejar")));
      MULTIDEX_JAR = Paths.get(runfiles.rlocation(System.getProperty("multidexjar")));
      JSIMPLE_JAR = Paths.get(runfiles.rlocation(System.getProperty("jsimplejar")));
      FIELDS_TYPES_JAR = Paths.get(runfiles.rlocation(System.getProperty("fields_types_jar")));
    } catch (Exception e) {
      throw new ExceptionInInitializerError(e);
    }
  }

  private Path simpleDexArchive;
  private Path multidexArchive;
  private Path jsimpleDexArchive;
  private Path fieldsTypesDexArchive;

  @Before
  public void setUp() throws Exception {
    simpleDexArchive = buildDexArchive(SIMPLE_JAR, "simple.dex.zip");
    multidexArchive = buildDexArchive(MULTIDEX_JAR, "multidex.dex.zip");
    jsimpleDexArchive = buildDexArchive(JSIMPLE_JAR, "jsimple.dex.zip");
    fieldsTypesDexArchive = buildDexArchive(FIELDS_TYPES_JAR, "fields_types.dex.zip");
  }

  @Test
  public void testSingleInputSingleOutput() throws Exception {
    ImmutableList<Path> outputArchives =
        runDexSplitter(REAL_WORLD_IDX_PER_DEX, "from_single", simpleDexArchive);
    assertThat(outputArchives).hasSize(1);

    ImmutableSet<String> expectedFiles = dexEntries(simpleDexArchive);
    assertThat(dexEntries(outputArchives.get(0))).containsExactlyElementsIn(expectedFiles);
  }

  @Test
  public void testDuplicateInputIgnored() throws Exception {
    ImmutableList<Path> outputArchives =
        runDexSplitter(
            REAL_WORLD_IDX_PER_DEX, "from_duplicate", simpleDexArchive, simpleDexArchive);
    assertThat(outputArchives).hasSize(1);

    ImmutableSet<String> expectedFiles = dexEntries(simpleDexArchive);
    assertThat(dexEntries(outputArchives.get(0))).containsExactlyElementsIn(expectedFiles);
  }

  @Test
  public void testSingleInputMultidexOutput() throws Exception {
    ImmutableList<Path> outputArchives =
        runDexSplitter(SMALL_IDX_PER_DEX, "multidex_from_single", multidexArchive);
    assertThat(outputArchives.size()).isGreaterThan(1);

    ImmutableSet<String> expectedEntries = dexEntries(multidexArchive);
    assertExpectedEntries(outputArchives, expectedEntries);
  }

  @Test
  public void testMultipleInputsMultidexOutput() throws Exception {
    ImmutableList<Path> outputArchives =
        runDexSplitter(SMALL_IDX_PER_DEX, "multidex", multidexArchive, simpleDexArchive);
    assertThat(outputArchives.size()).isGreaterThan(1);

    HashSet<String> expectedEntries = new HashSet<>();
    expectedEntries.addAll(dexEntries(multidexArchive));
    expectedEntries.addAll(dexEntries(simpleDexArchive));
    assertExpectedEntries(outputArchives, expectedEntries);
  }

  /**
   * Tests that the same input creates identical output in 2 runs. Flakiness here would indicate
   * race conditions or other concurrency issues.
   */
  @Test
  public void testDeterminism() throws Exception {
    ImmutableList<Path> outputArchives =
        runDexSplitter(SMALL_IDX_PER_DEX, "det1", multidexArchive, simpleDexArchive);
    assertThat(outputArchives.size()).isGreaterThan(1);
    ImmutableList<Path> outputArchives2 =
        runDexSplitter(SMALL_IDX_PER_DEX, "det2", multidexArchive, simpleDexArchive);
    assertThat(outputArchives2).hasSize(outputArchives.size()); // paths differ though

    Path outputRoot2 = outputArchives2.get(0).getParent();
    for (Path outputArchive : outputArchives) {
      ImmutableList<ZipEntry> expectedEntries;
      try (ZipFile zip = new ZipFile(outputArchive.toFile())) {
        expectedEntries = zip.stream().collect(ImmutableList.<ZipEntry>toImmutableList());
      }
      ImmutableList<ZipEntry> actualEntries;
      try (ZipFile zip2 = new ZipFile(outputRoot2.resolve(outputArchive.getFileName()).toFile())) {
        actualEntries = zip2.stream().collect(ImmutableList.<ZipEntry>toImmutableList());
      }
      int len = expectedEntries.size();
      assertThat(actualEntries).hasSize(len);
      for (int i = 0; i < len; ++i) {
        ZipEntry expected = expectedEntries.get(i);
        ZipEntry actual = actualEntries.get(i);
        assertWithMessage(actual.getName()).that(actual.getName()).isEqualTo(expected.getName());
        assertWithMessage(actual.getName()).that(actual.getSize()).isEqualTo(expected.getSize());
        assertWithMessage(actual.getName()).that(actual.getCrc()).isEqualTo(expected.getCrc());
      }
    }
  }

  @Test
  public void testMainDexList() throws Exception {
    Path mainDexFile = tmp.newFile("main_dex_list.txt").toPath();
    Files.write(mainDexFile, ImmutableList.of("multidex/Class2.class"), UTF_8);

    ImmutableList<Path> outputArchives =
        runDexSplitter(
            SMALL_IDX_PER_DEX,
            /* inclusionFilterJar= */ null,
            "main_dex_list",
            mainDexFile,
            /* minimalMainDex= */ false,
            simpleDexArchive,
            multidexArchive);

    HashSet<String> expectedEntries = new HashSet<>();
    expectedEntries.addAll(dexEntries(simpleDexArchive));
    expectedEntries.addAll(dexEntries(multidexArchive));
    assertThat(outputArchives.size()).isGreaterThan(1);
    assertThat(dexEntries(outputArchives.get(0))).contains("multidex/Class2.class.dex");
    assertExpectedEntries(outputArchives, expectedEntries);
  }

  @Test
  public void testMainDexList_containsForbidden() throws Exception {
    Path mainDexFile = tmp.newFile("main_dex_list.txt").toPath();
    Files.write(mainDexFile, ImmutableList.of("com/google/Ok.class", "j$/my/Bad.class"), UTF_8);
    IllegalArgumentException e =
        assertThrows(
            IllegalArgumentException.class,
            () ->
                runDexSplitter(
                    REAL_WORLD_IDX_PER_DEX,
                    /* inclusionFilterJar= */ null,
                    "invalid_main_dex_list",
                    mainDexFile,
                    /* minimalMainDex= */ false,
                    simpleDexArchive));
    assertThat(e).hasMessageThat().contains("j$");
  }

  @Test
  public void testMinimalMainDex() throws Exception {
    Path mainDexFile = tmp.newFile("minimal_main_dex_list.txt").toPath();
    Files.write(mainDexFile, ImmutableList.of("multidex/Class1.class"), UTF_8);

    ImmutableList<Path> outputArchives =
        runDexSplitter(
            REAL_WORLD_IDX_PER_DEX,
            /* inclusionFilterJar= */ null,
            "minimal_main_dex",
            mainDexFile,
            /* minimalMainDex= */ true,
            multidexArchive);

    ImmutableSet<String> expectedEntries = dexEntries(multidexArchive);
    assertThat(outputArchives.size()).isGreaterThan(1);
    assertThat(dexEntries(outputArchives.get(0))).containsExactly("multidex/Class1.class.dex");
    assertExpectedEntries(outputArchives, expectedEntries);
  }

  @Test
  public void testInclusionFilterJar() throws Exception {
    ImmutableList<Path> outputArchives =
        runDexSplitter(
            REAL_WORLD_IDX_PER_DEX,
            SIMPLE_JAR,
            "filtered",
            /* mainDexList= */ null,
            /* minimalMainDex= */ false,
            multidexArchive,
            simpleDexArchive);

    // Only expect entries from the Jar we filtered by
    assertExpectedEntries(outputArchives, dexEntries(simpleDexArchive));
  }

  @Test
  public void testMixedInput_keptSeparate() throws Exception {
    ImmutableList<Path> outputArchives =
        runDexSplitter(
            REAL_WORLD_IDX_PER_DEX,
            "mixed_input",
            simpleDexArchive,
            jsimpleDexArchive,
            multidexArchive);
    assertThat(outputArchives).hasSize(3);
    assertThat(dexEntries(outputArchives.get(1))).containsExactly("j$/Foo.class.dex");
    assertThat(dexEntries(outputArchives.get(2))).contains("multidex/Class1.class.dex");
  }

  @Test
  public void testShuffledInputsDeterminism() throws Exception {
    // Run 1: Order A, B, C
    ImmutableList<Path> outputArchives1 =
        runDexSplitter(
            SMALL_IDX_PER_DEX,
            "shuffled_1",
            simpleDexArchive,
            jsimpleDexArchive,
            multidexArchive);

    // Run 2: Order C, A, B (inverted context)
    ImmutableList<Path> outputArchives2 =
        runDexSplitter(
            SMALL_IDX_PER_DEX,
            "shuffled_2",
            multidexArchive,
            simpleDexArchive,
            jsimpleDexArchive);

    assertThat(outputArchives1).hasSize(outputArchives2.size());

    for (int i = 0; i < outputArchives1.size(); i++) {
      ImmutableSet<String> entries1 = dexEntries(outputArchives1.get(i));
      ImmutableSet<String> entries2 = dexEntries(outputArchives2.get(i));
      assertThat(entries1).containsExactlyElementsIn(entries2);
    }
  }

  @Test
  public void testErrorPropagation() throws Exception {
    Path corruptZip = tmp.newFile("corrupt.zip").toPath();
    try (ZipOutputStream zos = new ZipOutputStream(Files.newOutputStream(corruptZip))) {
      ZipEntry entry = new ZipEntry("com/example/Corrupt.class.dex");
      entry.setMethod(ZipEntry.STORED);
      byte[] junk = "not a valid dex file".getBytes(UTF_8);
      entry.setSize(junk.length);
      CRC32 crc = new CRC32();
      crc.update(junk);
      entry.setCrc(crc.getValue());
      zos.putNextEntry(entry);
      zos.write(junk);
      zos.closeEntry();
    }

    // We expect DexFileSplitter to fail because the content is not a valid DEX file.
    // Dex(byte[]) throws Exception or DexException when it fails to parse.
    assertThrows(
        Exception.class,
        () -> runDexSplitter(REAL_WORLD_IDX_PER_DEX, "corrupt_run", corruptZip));
  }

  @Test
  public void testFieldsTypesOverflow() throws Exception {
    // fieldsTypesDexArchive has 10 fields.
    // simpleDexArchive has 1 field.
    // Combined they have 11 fields.
    // Setting maxNumberOfIdxPerDex to 10 should trigger overflow when adding simpleDexArchive!
    ImmutableList<Path> outputArchives =
        runDexSplitter(10, "fields_types_overflow", fieldsTypesDexArchive, simpleDexArchive);

    // It should split into 2 shards.
    assertThat(outputArchives).hasSize(2);
  }

  @Test
  public void testShardTrackingContinuity() throws Exception {
    // multidexArchive has 4 classes with 60 methods each (total 240).
    // With limit 100, combined pairs of classes will exceed limit (60 + 60 = 120 > 100).
    // It should produce 4 shards if tracking is correct across shards.
    // Shard 1: Class 1
    // Shard 2: Class 2
    // Shard 3: Class 3
    // Shard 4: Class 4
    ImmutableList<Path> outputArchives =
        runDexSplitter(100, "shard_tracking_continuity", multidexArchive);

    assertThat(outputArchives).hasSize(4);
  }



  @Test
  public void testMultidexOffWithMultidexFlags() throws Exception {
    IllegalArgumentException e =
        assertThrows(
            IllegalArgumentException.class,
            () ->
                runDexSplitter(
                    SMALL_IDX_PER_DEX,
                    /* inclusionFilterJar= */ null,
                    "should_fail",
                    /* mainDexList= */ null,
                    /* minimalMainDex= */ true,
                    simpleDexArchive));
    assertThat(e)
        .hasMessageThat()
        .isEqualTo("--minimal-main-dex not allowed without --main-dex-list");
  }

  private void assertExpectedEntries(
      ImmutableList<Path> outputArchives, Set<String> expectedEntries) throws IOException {
    ImmutableSet.Builder<String> actualFiles = ImmutableSet.builder();
    for (Path outputArchive : outputArchives) {
      actualFiles.addAll(dexEntries(outputArchive));
    }
    // ImmutableSet.Builder.build would fail if there were duplicates.  Additionally we make sure
    // all expected files are here
    assertThat(actualFiles.build()).containsExactlyElementsIn(expectedEntries);
  }

  private ImmutableSet<String> dexEntries(Path dexArchive) throws IOException {
    try (ZipFile input = new ZipFile(dexArchive.toFile())) {
      ImmutableSet<String> result =
          input.stream()
              .map(ZipEntry::getName)
              .filter(Predicates.containsPattern(".*\\.class.dex$"))
              .collect(ImmutableSet.<String>toImmutableSet());
      assertThat(result).isNotEmpty();
      return result;
    }
  }

  private ImmutableList<Path> runDexSplitter(
      int maxNumberOfIdxPerDex, String outputRoot, Path... dexArchives)
      throws ExecutionException, InterruptedException, IOException {
    return runDexSplitter(
        maxNumberOfIdxPerDex,
        /*inclusionFilterJar=*/ null,
        outputRoot,
        /*mainDexList=*/ null,
        /*minimalMainDex=*/ false,
        dexArchives);
  }

  private ImmutableList<Path> runDexSplitter(
      int maxNumberOfIdxPerDex,
      @Nullable Path inclusionFilterJar,
      String outputRoot,
      @Nullable Path mainDexList,
      boolean minimalMainDex,
      Path... dexArchives)
      throws ExecutionException, InterruptedException, IOException {
    DexFileSplitter.Options options = new DexFileSplitter.Options();
    options.inputArchives = ImmutableList.copyOf(dexArchives);
    options.outputDirectory = tmp.newFolder(outputRoot).toPath();
    options.maxNumberOfIdxPerDex = maxNumberOfIdxPerDex;
    options.mainDexListFile = mainDexList;
    options.minimalMainDex = minimalMainDex;
    options.inclusionFilterJar = inclusionFilterJar;
    DexFileSplitter.splitIntoShards(options);
    assertThat(options.outputDirectory.toFile().exists()).isTrue();
    ImmutableSet<Path> files = readFiles(options.outputDirectory, "*.zip");

    ImmutableList.Builder<Path> result = ImmutableList.builder();
    for (int i = 1; i <= files.size(); ++i) {
      Path path = options.outputDirectory.resolve(i + ".shard.zip");
      assertThat(files).contains(path);
      result.add(path);
    }
    return result.build(); // return expected files in sorted order
  }

  private static ImmutableSet<Path> readFiles(Path directory, String glob) throws IOException {
    try (DirectoryStream<Path> stream = Files.newDirectoryStream(directory, glob)) {
      return ImmutableSet.copyOf(stream);
    }
  }

  private Path buildDexArchive(Path inputJar, String outputZip) throws Exception {
    // Use Jar file that has this test in it as the input Jar
    Path outputZipPath = tmp.getRoot().toPath().resolve(outputZip);
    int maxThreads = 1;
    String positionInfo = "lines"; // com.android.dx.dex.code.PositionList.LINES;
    CompatDexBuilder.main(
        new String[] {
          "--input_jar",
          inputJar.toString(),
          "--output_zip",
          outputZipPath.toString(),
          "--num-threads=" + Integer.toString(maxThreads),
          "--positions=" + positionInfo
        });
    return outputZipPath;
  }
}
