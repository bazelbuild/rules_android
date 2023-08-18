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
package com.google.devtools.build.android.sandboxedsdktoolbox;

import com.google.devtools.build.android.sandboxedsdktoolbox.apidescriptors.ExtractApiDescriptorsCommand;
import com.google.devtools.build.android.sandboxedsdktoolbox.sdkdependenciesmanifest.GenerateSdkDependenciesManifestCommand;
import picocli.CommandLine;
import picocli.CommandLine.Command;

/** Entrypoint for the Sandboxed SDK Toolbox binary. */
@Command(
    name = "sandboxed-sdk-toolbox",
    subcommands = {
      ExtractApiDescriptorsCommand.class,
      GenerateSdkDependenciesManifestCommand.class,
    })
public final class SandboxedSdkToolbox {

  public static final CommandLine create() {
    return new CommandLine(new SandboxedSdkToolbox());
  }

  public static final void main(String[] args) {
    SandboxedSdkToolbox.create().execute(args);
  }

  private SandboxedSdkToolbox() {}
}
