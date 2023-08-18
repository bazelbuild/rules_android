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
package com.google.devtools.build.android.sandboxedsdktoolbox.apidescriptors;

import static com.google.common.collect.ImmutableList.toImmutableList;
import static com.google.common.truth.Truth.assertThat;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Runner.runCommand;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.TestData.JAVATESTS_DIR;

import com.google.common.collect.ImmutableList;
import com.google.devtools.build.android.sandboxedsdktoolbox.utils.CommandResult;
import java.nio.file.Path;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class ExtractApiDescriptorsCommandTest {
  @Rule public final TemporaryFolder testFolder = new TemporaryFolder();

  private static final Path TEST_LIBRARY_DEPLOY_JAR =
      JAVATESTS_DIR.resolve(
          Path.of(
              "com/google/devtools/build/android/sandboxedsdktoolbox",
              "apidescriptors/testlibrary/libtestlibrary.jar"));

  @Test
  public void extractApiDescriptors_keepsAnnotatedClassesInDescriptors() throws Exception {
    Path outputFile = testFolder.getRoot().toPath().resolve("output.jar");

    CommandResult result =
        runCommand(
            "extract-api-descriptors",
            "--sdk-deploy-jar",
            TEST_LIBRARY_DEPLOY_JAR.toString(),
            "--output-sdk-api-descriptors",
            outputFile.toString());
    ImmutableList<String> outputJarEntryNames =
        new ZipFile(outputFile.toFile()).stream().map(ZipEntry::getName).collect(toImmutableList());

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
    assertThat(outputJarEntryNames)
        .containsExactly(
            "com/google/devtools/build/android/sandboxedsdktoolbox/apidescriptors/"
                + "testlibrary/AnnotatedClass.class");
  }
}
