// Copyright 2020 The Bazel Authors. All rights reserved.
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
package com.google.devtools.build.android.xml;

import static com.google.common.truth.Truth.assertThat;

import com.android.aapt.Resources.Reference;
import com.android.aapt.Resources.XmlAttribute;
import com.android.aapt.Resources.XmlElement;
import com.android.aapt.Resources.XmlNode;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TemporaryFolder;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

/** Unit tests for {@link XmlUtils}. */
@RunWith(JUnit4.class)
public final class XmlUtilsTest {

  @Rule public final TemporaryFolder tempFolder = new TemporaryFolder();

  @Test
  public void parseAttributeNameReference() {
    assertThat(
            XmlUtils.parseAttributeNameReference("http://schemas.android.com/apk/res-auto", "foo"))
        .hasValue(Reference.newBuilder().setName("attr/foo").build());
    assertThat(
            XmlUtils.parseAttributeNameReference(
                "http://schemas.android.com/apk/res/android", "foo"))
        .hasValue(Reference.newBuilder().setName("android:attr/foo").build());
    assertThat(
            XmlUtils.parseAttributeNameReference(
                "http://schemas.android.com/apk/prv/res/android", "foo"))
        .hasValue(Reference.newBuilder().setPrivate(true).setName("android:attr/foo").build());

    assertThat(XmlUtils.parseAttributeNameReference("", "foo")).isEmpty();
    assertThat(XmlUtils.parseAttributeNameReference("http://asdf", "foo")).isEmpty();
  }

  @Test
  public void parseResourceReference() {
    assertThat(XmlUtils.parseResourceReference("@string/foo"))
        .hasValue(
            Reference.newBuilder().setType(Reference.Type.REFERENCE).setName("string/foo").build());
    assertThat(XmlUtils.parseResourceReference("?*android:attr/foo"))
        .hasValue(
            Reference.newBuilder()
                .setType(Reference.Type.ATTRIBUTE)
                .setPrivate(true)
                .setName("android:attr/foo")
                .build());

    assertThat(XmlUtils.parseResourceReference("x")).isEmpty();
    assertThat(XmlUtils.parseResourceReference("@")).isEmpty();
    assertThat(XmlUtils.parseResourceReference("@x")).isEmpty();
    assertThat(XmlUtils.parseResourceReference("@x/foo")).isEmpty();
  }

  @Test
  public void getAllResourceReferences() {
    XmlNode root =
        XmlNode.newBuilder()
            .setElement(
                XmlElement.newBuilder()
                    .addAttribute(
                        XmlAttribute.newBuilder()
                            .setNamespaceUri("http://schemas.android.com/apk/res/android")
                            .setName("text")
                            .setValue("asdf"))
                    .addChild(
                        XmlNode.newBuilder()
                            .setElement(
                                XmlElement.newBuilder()
                                    .addAttribute(
                                        XmlAttribute.newBuilder()
                                            .setName("id")
                                            .setValue("@string/foo")))))
            .build();

    assertThat(XmlUtils.getAllResourceReferences(root))
        .containsExactly(
            Reference.newBuilder().setName("android:attr/text").build(),
            Reference.newBuilder().setName("string/foo").build());
  }

  @Test
  public void getAllResourceReferences_manifestPath() throws Exception {
    Path manifestPath = tempFolder.newFile("AndroidManifest.xml").toPath();
    Files.writeString(
        manifestPath,
        "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\""
            + " android:text=\"asdf\">\n"
            + "  <application id=\"@string/foo\"/>\n"
            + "</manifest>");

    assertThat(XmlUtils.getAllResourceReferences(manifestPath))
        .containsExactly(
            Reference.newBuilder().setName("android:attr/text").build(),
            Reference.newBuilder().setName("string/foo").build());
  }
}
