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
package com.google.devtools.build.android.dexer;

import static com.google.common.truth.Truth.assertThat;
import static org.junit.Assert.assertSame;
import static org.junit.Assert.assertTrue;

import com.android.dex.Dex;
import com.google.devtools.build.android.dexer.DexLimitTracker.DexTrackerInfo;
import com.google.devtools.build.android.r8.CompatDexBuilder;
import com.google.devtools.build.runfiles.Runfiles;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import org.junit.Before;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

/** Tests for {@link DexLimitTracker}. */
@RunWith(JUnit4.class)
public class DexLimitTrackerTest {

  private static final Path SIMPLE_JAR;
  private static final Path FIELDS_TYPES_JAR;

  @Rule public TemporaryFolder tmp = new TemporaryFolder();

  static {
    try {
      Runfiles runfiles = Runfiles.preload().unmapped();
      SIMPLE_JAR = getRunfile(runfiles, "simplejar");
      FIELDS_TYPES_JAR = getRunfile(runfiles, "fields_types_jar");
    } catch (Exception e) {
      throw new ExceptionInInitializerError(e);
    }
  }

  private static Path getRunfile(Runfiles runfiles, String property) {
    String path = System.getProperty(property);
    String google3Path = runfiles.rlocation("google3/" + path);
    if (google3Path != null && Files.exists(Path.of(google3Path))) {
      return Path.of(google3Path);
    }
    String rulesAndroidPath = runfiles.rlocation("rules_android/" + path);
    if (rulesAndroidPath != null && Files.exists(Path.of(rulesAndroidPath))) {
      return Path.of(rulesAndroidPath);
    }
    throw new RuntimeException("Could not find runfile for property " + property + ": " + path);
  }

  private Path simpleDexArchive;
  private Path fieldsTypesDexArchive;

  @Before
  public void setUp() throws Exception {
    simpleDexArchive = buildDexArchive(SIMPLE_JAR, "simple.dex.zip");
    fieldsTypesDexArchive = buildDexArchive(FIELDS_TYPES_JAR, "fields_types.dex.zip");
  }

  private Path buildDexArchive(Path inputJar, String outputZip) throws Exception {
    Path outputZipPath = tmp.getRoot().toPath().resolve(outputZip);
    CompatDexBuilder.main(
        new String[] {
          "--input_jar",
          inputJar.toString(),
          "--output_zip",
          outputZipPath.toString(),
          "--num-threads=1",
          "--positions=lines"
        });
    return outputZipPath;
  }

  private Dex loadDexFromArchive(Path dexArchive) throws IOException {
    try (ZipFile zip = new ZipFile(dexArchive.toFile())) {
      ZipEntry entry =
          zip.stream()
              .filter(e -> e.getName().endsWith(".class.dex"))
              .findFirst()
              .orElseThrow(() -> new IOException("No .dex entry found"));
      try (InputStream is = zip.getInputStream(entry)) {
        return new Dex(is.readAllBytes());
      }
    }
  }

  @Test
  public void testTrackerInfoCreationAndTracking() throws Exception {
    Dex dex = loadDexFromArchive(simpleDexArchive);
    DexTrackerInfo info = DexTrackerInfo.create(dex);

    // Verify fields
    assertThat(info.fields).hasLength(1);
    assertThat(info.fields[0]).isEqualTo("Lbase/SimpleClass;.field:I");

    // Verify methods
    assertThat(info.methods)
        .hasLength(
            4); // constructor, method(), methodWithParams(int, String), and superclass constructor
    // Object.<init>
    assertThat(info.methods)
        .asList()
        .containsExactly(
            "Lbase/SimpleClass;.<init>:V()",
            "Lbase/SimpleClass;.method:V()",
            "Lbase/SimpleClass;.methodWithParams:V(ILjava/lang/String;)",
            "Ljava/lang/Object;.<init>:V()");

    // Verify types
    assertThat(info.types).asList().contains("Lbase/SimpleClass;");
  }

  @Test
  public void testMemoizationCache() throws Exception {
    Dex dex1 = loadDexFromArchive(simpleDexArchive);
    DexTrackerInfo info1 = DexTrackerInfo.create(dex1);

    Dex dex2 = loadDexFromArchive(simpleDexArchive);
    DexTrackerInfo info2 = DexTrackerInfo.create(dex2);

    // Verify that equal type names across tracker runs refer to the same String instance (interned)
    String type1 = null;
    for (String t : info1.types) {
      if (t.equals("Lbase/SimpleClass;")) {
        type1 = t;
      }
    }
    String type2 = null;
    for (String t : info2.types) {
      if (t.equals("Lbase/SimpleClass;")) {
        type2 = t;
      }
    }

    assertThat(type1).isNotNull();
    assertThat(type2).isNotNull();
    assertSame("Type names should be referentially equal (interned)", type1, type2);

    // Verify that equal field signatures across tracker runs refer to the same String instance
    assertSame(
        "Field signatures should be referentially equal (interned)",
        info1.fields[0],
        info2.fields[0]);

    // Verify that equal method signatures across tracker runs refer to the same String instance
    String[] methods1 = info1.methods.clone();
    String[] methods2 = info2.methods.clone();
    Arrays.sort(methods1);
    Arrays.sort(methods2);
    for (int i = 0; i < methods1.length; i++) {
      assertSame(
          "Method signatures should be referentially equal (interned)", methods1[i], methods2[i]);
    }
  }

  @Test
  public void testTrackCountsAndLimits() throws Exception {
    DexLimitTracker tracker = new DexLimitTracker(8); // low limit of 8
    Dex dexSimple = loadDexFromArchive(simpleDexArchive); // 1 field, 4 methods, some types
    Dex dexFieldsTypes =
        loadDexFromArchive(fieldsTypesDexArchive); // 10 fields, 2 methods, some types
    // Track simple dex first
    tracker.track(dexSimple);
    assertThat(tracker.outsideLimits()).isFalse();

    // Track fieldsTypes (10 fields) which exceeds limit of 8 fields/types
    tracker.track(dexFieldsTypes);
    assertThat(tracker.outsideLimits()).isTrue();

    // Verify clear resets tracking
    tracker.clear();
    assertThat(tracker.outsideLimits()).isFalse();
  }

  @Test
  public void testTrackerInfoImmutability() throws Exception {
    // Check that all fields of DexTrackerInfo are final
    Class<DexTrackerInfo> clazz = DexTrackerInfo.class;
    for (Field field : clazz.getDeclaredFields()) {
      // Ignore synthetic fields (like $jacocoData if code coverage is enabled)
      if (field.isSynthetic()) {
        continue;
      }
      int modifiers = field.getModifiers();
      assertTrue("Field " + field.getName() + " must be final", Modifier.isFinal(modifiers));
    }
  }
}
