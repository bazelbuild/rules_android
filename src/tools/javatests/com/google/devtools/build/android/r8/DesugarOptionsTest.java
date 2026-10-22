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

import static com.google.common.truth.Truth.assertThat;
import static org.junit.Assert.assertThrows;

import com.beust.jcommander.JCommander;
import com.beust.jcommander.ParameterException;
import com.google.devtools.build.android.r8.Desugar.DesugarOptions;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

/** Tests for the command line parsing of {@link Desugar}. */
@RunWith(JUnit4.class)
public class DesugarOptionsTest {
  @Rule public final TemporaryFolder temp = new TemporaryFolder();

  @Test
  public void classpathEntries() {
    DesugarOptions options =
        Desugar.parseCommandLineOptions(
            new String[] {
              "--classpath_entry",
              "a.jar",
              "--min_sdk_version",
              "21",
              "--bootclasspath_entry=boot1.jar",
              "--classpath_entry=b.jar",
              "--bootclasspath_entry",
              "boot2.jar",
              "--classpath_entry",
              "c.jar",
            });

    assertThat(options.classpath)
        .containsExactly(Path.of("a.jar"), Path.of("b.jar"), Path.of("c.jar"))
        .inOrder();
    assertThat(options.bootclasspath)
        .containsExactly(Path.of("boot1.jar"), Path.of("boot2.jar"))
        .inOrder();
    assertThat(options.minSdkVersion).isEqualTo(21);
  }

  @Test
  public void classpathEntryWithoutValue() {
    assertThrows(
        ParameterException.class,
        () -> Desugar.parseCommandLineOptions(new String[] {"--classpath_entry"}));
  }

  @Test
  public void classpathEntryInNestedParamsFile() throws Exception {
    // Only a params file which is the only argument is expanded before extracting the classpath.
    // Other params files are expanded by JCommander (if its version does that), and then rejected
    // rather than dropping the classpath entries in them.
    Path params = temp.newFile("params").toPath();
    Files.writeString(params, "--classpath_entry\na.jar\n");
    assertThrows(
        RuntimeException.class,
        () -> Desugar.parseCommandLineOptions(new String[] {"--min_sdk_version=21", "@" + params}));
  }

  // JCommander parses DesugarOptions with CompatPathConverter for the classpath flags, rather than
  // the CompatExistingPathConverter they used before, as entries are no longer checked to exist
  // while parsing.
  @Test
  public void sameAsJCommander() {
    String[] args = {
      "--classpath_entry",
      "a.jar,b.jar",
      "--classpath_entry=c.jar,d.jar",
      "--bootclasspath_entry",
      "boot1.jar",
      "--min_sdk_version=21",
      "--bootclasspath_entry=boot2.jar,boot3.jar",
      "--classpath_entry=",
      "--classpath_entry e.jar",
      "--classpath_entry=f.jar,",
    };
    DesugarOptions expected = new DesugarOptions();
    JCommander.newBuilder().addObject(expected).build().parse(args);

    DesugarOptions options = Desugar.parseCommandLineOptions(args);

    assertThat(options.classpath).containsExactlyElementsIn(expected.classpath).inOrder();
    assertThat(options.bootclasspath).containsExactlyElementsIn(expected.bootclasspath).inOrder();
    assertThat(options.minSdkVersion).isEqualTo(expected.minSdkVersion);
  }
}
