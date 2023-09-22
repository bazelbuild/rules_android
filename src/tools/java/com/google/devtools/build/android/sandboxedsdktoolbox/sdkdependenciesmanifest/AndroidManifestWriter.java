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

import com.google.common.collect.ImmutableSet;
import com.google.devtools.build.android.sandboxedsdktoolbox.info.SdkInfo;
import java.io.BufferedOutputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Path;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import org.w3c.dom.Document;
import org.w3c.dom.Element;

/** Writes an Android manifest that lists SDK dependencies for an app. */
final class AndroidManifestWriter {

  private static final String ANDROID_NAME_ATTRIBUTE = "android:name";
  private static final String ANDROID_VERSION_MAJOR_ATTRIBUTE = "android:versionMajor";
  private static final String ANDROID_CERTIFICATE_DIGEST_ATTRIBUTE = "android:certDigest";
  private static final String APPLICATION_ELEMENT_NAME = "application";
  private static final String MANIFEST_ELEMENT_NAME = "manifest";
  private static final String MANIFEST_NAMESPACE_URI = "http://schemas.android.com/apk/res/android";
  private static final String MANIFEST_NAMESPACE_NAME = "xmlns:android";
  private static final String MANIFEST_PACKAGE_ATTRIBUTE = "package";
  private static final String SDK_DEPENDENCY_ELEMENT_NAME = "uses-sdk-library";

  static void writeManifest(
      String packageName,
      String certificateDigest,
      ImmutableSet<SdkInfo> infoSet,
      Path outputPath) {
    Document root = newEmptyDocument();

    Element manifestNode = root.createElement(MANIFEST_ELEMENT_NAME);
    manifestNode.setAttribute(MANIFEST_NAMESPACE_NAME, MANIFEST_NAMESPACE_URI);
    manifestNode.setAttribute(MANIFEST_PACKAGE_ATTRIBUTE, packageName);
    root.appendChild(manifestNode);

    Element applicationNode = root.createElement(APPLICATION_ELEMENT_NAME);
    manifestNode.appendChild(applicationNode);

    for (SdkInfo sdkInfo : infoSet) {
      Element sdkDependencyElement = root.createElement(SDK_DEPENDENCY_ELEMENT_NAME);
      sdkDependencyElement.setAttribute(ANDROID_NAME_ATTRIBUTE, sdkInfo.getPackageName());
      sdkDependencyElement.setAttribute(
          ANDROID_VERSION_MAJOR_ATTRIBUTE, Long.toString(sdkInfo.getVersionMajor()));
      sdkDependencyElement.setAttribute(ANDROID_CERTIFICATE_DIGEST_ATTRIBUTE, certificateDigest);
      applicationNode.appendChild(sdkDependencyElement);
    }

    writeDocument(root, outputPath);
  }

  private static Document newEmptyDocument() {
    try {
      return DocumentBuilderFactory.newInstance().newDocumentBuilder().newDocument();
    } catch (ParserConfigurationException e) {
      throw new IllegalStateException("Failed to create new XML document.", e);
    }
  }

  private static void writeDocument(Document document, Path outputPath) {
    try (BufferedOutputStream outputStream =
        new BufferedOutputStream(new FileOutputStream(outputPath.toFile()))) {
      Transformer transformer = TransformerFactory.newInstance().newTransformer();
      transformer.setOutputProperty(OutputKeys.ENCODING, "utf-8");
      transformer.setOutputProperty(OutputKeys.METHOD, "xml");
      transformer.setOutputProperty(OutputKeys.INDENT, "yes");
      transformer.transform(new DOMSource(document), new StreamResult(outputStream));
    } catch (TransformerException | IOException e) {
      throw new IllegalStateException("Failed to write manifest.", e);
    }
  }

  private AndroidManifestWriter() {}
}
