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

import com.android.bundle.SdkModulesConfigOuterClass.RuntimeEnabledSdkVersion;
import com.android.tools.build.bundletool.model.RuntimeEnabledSdkVersionEncoder;
import java.util.Objects;
import java.util.Optional;

/**
 * Information about a Sandboxed SDK. Used to define an SDK dependency and read from an SDK archive
 * or bundle config.
 */
public final class SdkInfo {

  private final String packageName;
  private final RuntimeEnabledSdkVersion version;
  private final Optional<String> certificateDigest;
  private final Optional<String> sdkProviderClassName;
  private final Optional<String> compatSdkProviderClassName;

  SdkInfo(
      String packageName,
      RuntimeEnabledSdkVersion version,
      String sdkProviderClassName,
      String compatSdkProviderClassName) {
    this(
        packageName,
        version,
        Optional.empty(),
        Optional.ofNullable(sdkProviderClassName),
        Optional.ofNullable(compatSdkProviderClassName));
  }

  SdkInfo(String packageName, RuntimeEnabledSdkVersion version, String certificateDigest) {
    this(packageName, version, Optional.of(certificateDigest), Optional.empty(), Optional.empty());
  }

  private SdkInfo(
      String packageName,
      RuntimeEnabledSdkVersion version,
      Optional<String> certificateDigest,
      Optional<String> sdkProviderClassName,
      Optional<String> compatSdkProviderClassName) {
    this.packageName = packageName;
    this.version = version;
    this.certificateDigest = certificateDigest;
    this.sdkProviderClassName = sdkProviderClassName;
    this.compatSdkProviderClassName = compatSdkProviderClassName;
  }

  /** The SDK unique package name. */
  public String getPackageName() {
    return packageName;
  }

  public RuntimeEnabledSdkVersion getVersion() {
    return version;
  }

  /**
   * The SDK encoded version major-minor.
   *
   * <p>This value is constructed from the full SDK version description and it represents the actual
   * version of the SDK as used by the package manager later. The major and minor versions are
   * merged and the patch version is ignored.
   */
  public long getEncodedVersionMajorMinor() {
    return RuntimeEnabledSdkVersionEncoder.encodeSdkMajorAndMinorVersion(
        version.getMajor(), version.getMinor());
  }

  /**
   * Digest of certificate used to sign this SDK's APKs.
   *
   * <p>Might be missing if the certificate is not known at the time, for example for SDKs signed
   * with debug keys for local deployment.
   */
  public Optional<String> getCertificateDigest() {
    return certificateDigest;
  }

  /** The fully qualified name for the platform SDK provider entrypoint class. */
  public Optional<String> getSdkProviderClassName() {
    return sdkProviderClassName;
  }

  /** The fully qualified name for the compatibility SDK provider entrypoint class. */
  public Optional<String> getCompatSdkProviderClassName() {
    return compatSdkProviderClassName;
  }

  @Override
  @SuppressWarnings("PatternMatchingInstanceof")
  public boolean equals(Object object) {
    if (object instanceof SdkInfo) {
      SdkInfo that = (SdkInfo) object;
      return this.packageName.equals(that.packageName)
          && this.version.equals(that.version)
          && this.certificateDigest.equals(that.certificateDigest)
          && this.sdkProviderClassName.equals(that.sdkProviderClassName)
          && this.compatSdkProviderClassName.equals(that.compatSdkProviderClassName);
    }
    return false;
  }

  @Override
  public int hashCode() {
    return Objects.hash(
        packageName, version, certificateDigest, sdkProviderClassName, compatSdkProviderClassName);
  }
}
