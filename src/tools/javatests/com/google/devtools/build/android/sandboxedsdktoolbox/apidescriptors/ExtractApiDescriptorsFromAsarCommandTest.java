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

import static com.google.common.truth.Truth.assertThat;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Runner.runCommand;
import static com.google.devtools.build.android.sandboxedsdktoolbox.utils.Zip.createZipWithSingleEntry;
import static java.nio.charset.StandardCharsets.UTF_8;

import com.google.devtools.build.android.sandboxedsdktoolbox.utils.CommandResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class ExtractApiDescriptorsFromAsarCommandTest {

  @Rule public final TemporaryFolder testFolder = new TemporaryFolder();

  @Test
  public void extractApiDescriptors_fromValidAsar() throws Exception {
    Path asar = Paths.get(testFolder.getRoot().getAbsolutePath(), "test.asar");
    byte[] sdkApiDescriptorContents = "fake descriptor contents".getBytes(UTF_8);
    Path outputDescriptors = Paths.get(testFolder.getRoot().getAbsolutePath(), "descriptors.jar");
    createZipWithSingleEntry(asar, "sdk-interface-descriptors.jar", sdkApiDescriptorContents);

    CommandResult result =
        runCommand(
            "extract-api-descriptors-from-asar",
            "--asar",
            asar.toString(),
            "--output-sdk-api-descriptors",
            outputDescriptors.toString());

    assertThat(result.getStatusCode()).isEqualTo(0);
    assertThat(result.getOutput()).isEmpty();
    assertThat(Files.readAllBytes(outputDescriptors)).isEqualTo(sdkApiDescriptorContents);
  }
}
