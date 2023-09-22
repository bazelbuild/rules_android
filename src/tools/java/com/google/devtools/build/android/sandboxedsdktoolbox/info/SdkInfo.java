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
package com.google.devtools.build.android.sandboxedsdktoolbox.info;

import java.util.Objects;

/**
 * Information about a Sandboxed SDK. Used to define an SDK dependency and read from an SDK archive
 * or bundle config.
 */
public final class SdkInfo {

  private final String packageName;
  private final long versionMajor;

  SdkInfo(String packageName, long versionMajor) {
    this.packageName = packageName;
    this.versionMajor = versionMajor;
  }

  /** The SDK unique package name. */
  public String getPackageName() {
    return packageName;
  }

  /**
   * The SDK versionMajor. This value is constructed from the full SDK version description and it
   * represents the actual version of the SDK as used by the package manager later. The major and
   * minor versions are merged and the patch version is ignored.
   */
  public long getVersionMajor() {
    return versionMajor;
  }

  @Override
  public boolean equals(Object object) {
    if (object instanceof SdkInfo) {
      SdkInfo that = (SdkInfo) object;
      return this.packageName.equals(that.packageName) && this.versionMajor == that.versionMajor;
    }
    return false;
  }

  @Override
  public int hashCode() {
    return Objects.hash(packageName, versionMajor);
  }
}
