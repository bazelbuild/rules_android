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
package com.google.devtools.build.android.sandboxedsdktoolbox.utils;

import com.google.devtools.build.android.sandboxedsdktoolbox.SandboxedSdkToolbox;
import java.io.PrintWriter;
import java.io.StringWriter;
import picocli.CommandLine;

/** Utilities for running SandboxedSdkToolbox commands. */
public final class Runner {
  public static CommandResult runCommand(String... parameters) {
    CommandLine command = SandboxedSdkToolbox.create();
    StringWriter stringWriter = new StringWriter();

    command.setOut(new PrintWriter(stringWriter));
    int statusCode = command.execute(parameters);
    String output = stringWriter.toString();

    return new CommandResult(statusCode, output);
  }

  private Runner() {}
}
