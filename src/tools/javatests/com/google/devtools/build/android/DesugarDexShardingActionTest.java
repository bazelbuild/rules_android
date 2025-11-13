// Copyright 2025 The Bazel Authors. All rights reserved.
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
import static com.google.common.truth.Truth.assertWithMessage;

import com.google.common.base.Joiner;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

@RunWith(JUnit4.class)
public final class DesugarDexShardingActionTest {
  private Path runfilesBase;
  private Path androidJar;
  private Path classpath;
  private Path in;

  @Before
  public void setup() {
    runfilesBase = Path.of(System.getenv("TEST_SRCDIR"), System.getenv("TEST_WORKSPACE"));
    androidJar =
        Path.of(
            runfilesBase.toString(),
            "third_party/java/android/android_sdk_linux/platforms/stable/android.jar");
    classpath =
        Path.of(
            runfilesBase.toString(),
            "third_party/bazel_rules/rules_android/src/tools/java/com/google/devtools/build/android/libandroid_builder_lib.jar");
    in =
        Path.of(
            runfilesBase.toString(),
            "third_party/bazel_rules/rules_android/src/tools/java/com/google/devtools/build/android/DesugarDexShardingAction.jar");
  }

  private List<Path> createOutputFiles(int shardCount) throws IOException {
    List<Path> outs = new ArrayList<>();
    for (int i = 0; i < shardCount; i++) {
      outs.add(Files.createTempFile("out", ".zip"));
    }
    return outs;
  }

  private List<String> createArgs(List<Path> outs) {
    List<String> args = new ArrayList<>();
    args.add("-android_jar=" + androidJar);
    args.add("-in=" + in);
    args.add("-classpath=" + classpath);
    args.add("-out=" + Joiner.on(",").join(outs));
    return args;
  }

  @Test
  public void testPathsAreValid() {
    assertThat(this.androidJar.toFile().exists()).isTrue();
    assertThat(this.classpath.toFile().exists()).isTrue();
    assertThat(this.in.toFile().exists()).isTrue();
  }

  private void runDesugarDexSharding(int shardCount) throws Exception {
    // Runs the deploy jar for the desugar dex sharding action.
    // NOTE: The deploy jar is used here instead of directly calling its main(), since the desugar
    // and dexbuilder tools invoke System.exit(), which causes the JUnit test runner to prematurely
    // exit.
    List<Path> outs = createOutputFiles(shardCount);
    List<String> args = createArgs(outs);

    DesugarDexShardingAction.main(args.toArray(new String[0]));

    for (Path out : outs) {
      assertWithMessage("Output zip %s does not exist", out).that(out.toFile().exists()).isTrue();
      assertWithMessage("Output zip %s is empty", out).that(out.toFile().length()).isGreaterThan(0);
    }
  }

  @Test
  public void testOneShard() throws Exception {
    runDesugarDexSharding(1);
  }

  @Test
  public void testStandardDexDesugar() throws Exception {
    runDesugarDexSharding(32);
  }
}
