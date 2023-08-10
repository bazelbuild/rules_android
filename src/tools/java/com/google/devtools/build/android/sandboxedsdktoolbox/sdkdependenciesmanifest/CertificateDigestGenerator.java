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
package com.google.devtools.build.android.sandboxedsdktoolbox.sdkdependenciesmanifest;

import static java.util.stream.Collectors.joining;

import com.google.common.hash.Hashing;
import com.google.common.io.ByteSource;
import com.google.common.primitives.Bytes;
import java.io.BufferedInputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.GeneralSecurityException;
import java.security.KeyStore;
import java.security.cert.CertificateEncodingException;
import java.security.cert.X509Certificate;

/** Generates a SHA256 digest of a signing certificate. */
final class CertificateDigestGenerator {

  static final String generateCertificateDigest(
      Path keystorePath, String keystorePassword, String keystoreAlias) {
    X509Certificate certificate = readCertificate(keystorePath, keystorePassword, keystoreAlias);
    return getCertificateDigest(certificate);
  }

  private static X509Certificate readCertificate(
      Path keystorePath, String keystorePassword, String keystoreAlias) {
    try (BufferedInputStream keystoreInputStream =
        new BufferedInputStream(Files.newInputStream(keystorePath))) {
      KeyStore keystore = KeyStore.getInstance("JKS");
      keystore.load(keystoreInputStream, keystorePassword.toCharArray());
      return (X509Certificate) keystore.getCertificate(keystoreAlias);
    } catch (GeneralSecurityException | IOException e) {
      throw new IllegalStateException("Failed to read certificate", e);
    }
  }

  private static String getCertificateDigest(X509Certificate certificate) {
    try {
      return Bytes.asList(
              ByteSource.wrap(certificate.getEncoded()).hash(Hashing.sha256()).asBytes())
          .stream()
          .map(b -> String.format("%02X", b))
          .collect(joining(":"));
    } catch (CertificateEncodingException | IOException e) {
      throw new IllegalStateException("Failed to generate certificate digest", e);
    }
  }

  private CertificateDigestGenerator() {}
}
