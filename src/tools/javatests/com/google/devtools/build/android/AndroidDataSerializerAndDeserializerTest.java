// Copyright 2017 The Bazel Authors. All rights reserved.
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
import static com.google.devtools.build.android.ParsedAndroidDataBuilder.file;
import static com.google.devtools.build.android.ParsedAndroidDataBuilder.xml;

import com.android.aapt.ConfigurationOuterClass.Configuration;
import com.android.aapt.ConfigurationOuterClass.Configuration.KeysHidden;
import com.android.aapt.ConfigurationOuterClass.Configuration.NavHidden;
import com.android.aapt.ConfigurationOuterClass.Configuration.Orientation;
import com.android.aapt.ConfigurationOuterClass.Configuration.ScreenLayoutLong;
import com.android.aapt.ConfigurationOuterClass.Configuration.ScreenLayoutSize;
import com.android.aapt.ConfigurationOuterClass.Configuration.ScreenRound;
import com.android.aapt.ConfigurationOuterClass.Configuration.Touchscreen;
import com.android.aapt.ConfigurationOuterClass.Configuration.UiModeNight;
import com.android.aapt.ConfigurationOuterClass.Configuration.UiModeType;
import com.google.common.base.MoreObjects;
import com.google.common.collect.ImmutableList;
import com.google.common.jimfs.Jimfs;
import com.google.devtools.build.android.xml.IdXmlResourceValue;
import com.google.devtools.build.android.xml.ResourcesAttribute;
import java.nio.file.FileSystem;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Collection;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

/** Tests for the AndroidDataSerializer and AndroidDataDeserializer. */
@RunWith(JUnit4.class)
public class AndroidDataSerializerAndDeserializerTest {

  private FileSystem fs;
  private FullyQualifiedName.Factory fqnFactory;
  private Path source;
  private Path manifest;

  @Before
  public void createCleanEnvironment() throws Exception {
    fs = Jimfs.newFileSystem();
    fqnFactory = FullyQualifiedName.Factory.from(ImmutableList.<String>of());
    source = Files.createDirectory(fs.getPath("source"));
    manifest = Files.createFile(source.resolve("AndroidManifest.xml"));
  }

  @Test
  public void serializeAssets() throws Exception {
    Path binaryPath = fs.getPath("out.bin");
    AndroidDataSerializer serializer = AndroidDataSerializer.create();
    UnwrittenMergedAndroidData expected =
        UnwrittenMergedAndroidData.of(
            manifest,
            ParsedAndroidDataBuilder.buildOn(source)
                .assets(file().source("hunting/of/the/boojum"))
                .build(),
            ParsedAndroidDataBuilder.empty());
    expected.serializeTo(serializer);
    serializer.flushTo(binaryPath);

    AndroidDataDeserializer deserializer = AndroidParsedDataDeserializer.create();
    TestMapConsumer<DataAsset> assets = TestMapConsumer.ofAssets();
    deserializer.read(binaryPath, KeyValueConsumers.of(null, null, assets));
    assertThat(assets).isEqualTo(expected.getPrimary().getAssets());
  }

  @Test
  public void serializeCombiningResource() throws Exception {
    Path binaryPath = fs.getPath("out.bin");
    AndroidDataSerializer serializer = AndroidDataSerializer.create();
    UnwrittenMergedAndroidData expected =
        UnwrittenMergedAndroidData.of(
            manifest,
            ParsedAndroidDataBuilder.buildOn(source, fqnFactory)
                .combining(
                    xml("id/snark").source("values/ids.xml").value(IdXmlResourceValue.of()))
                .build(),
            ParsedAndroidDataBuilder.empty());
    expected.serializeTo(serializer);
    serializer.flushTo(binaryPath);

    AndroidDataDeserializer deserializer = AndroidParsedDataDeserializer.create();
    TestMapConsumer<DataResource> resources = TestMapConsumer.ofResources();
    deserializer.read(
        binaryPath,
        KeyValueConsumers.of(
            null, // overwriting
            resources, // combining
            null // assets
            ));
    assertThat(resources).isEqualTo(expected.getPrimary().getCombiningResources());
  }

  @Test
  public void serializeOverwritingResource() throws Exception {
    Path binaryPath = fs.getPath("out.bin");
    AndroidDataSerializer serializer = AndroidDataSerializer.create();
    UnwrittenMergedAndroidData expected =
        UnwrittenMergedAndroidData.of(
            manifest,
            ParsedAndroidDataBuilder.buildOn(source, fqnFactory)
                .overwritable(file("layout/banker").source("layout/banker.xml"))
                .build(),
            ParsedAndroidDataBuilder.empty());
    expected.serializeTo(serializer);
    serializer.flushTo(binaryPath);

    AndroidDataDeserializer deserializer = AndroidParsedDataDeserializer.create();
    TestMapConsumer<DataResource> resources = TestMapConsumer.ofResources();
    deserializer.read(
        binaryPath,
        KeyValueConsumers.of(
            resources, // overwriting
            null, // combining
            null // assets
            ));
    assertThat(resources).isEqualTo(expected.getPrimary().getOverwritingResources());
  }

  @Test
  public void serializeFileWithIds() throws Exception {
    Path binaryPath = fs.getPath("out.bin");
    AndroidDataSerializer serializer = AndroidDataSerializer.create();
    ParsedAndroidData direct =
        AndroidDataBuilder.of(source)
            .addResource(
                "layout/some_layout.xml",
                AndroidDataBuilder.ResourceType.LAYOUT,
                "<TextView android:id=\"@+id/MyTextView\"",
                "          android:text=\"@string/walrus\"",
                "          android:layout_width=\"wrap_content\"",
                "          android:layout_height=\"wrap_content\" />")
            // Test what happens if a user accidentally uses the same ID in multiple layouts too.
            .addResource(
                "layout/another_layout.xml",
                AndroidDataBuilder.ResourceType.LAYOUT,
                "<TextView android:id=\"@+id/MyTextView\"",
                "          android:text=\"@string/walrus\"",
                "          android:layout_width=\"wrap_content\"",
                "          android:layout_height=\"wrap_content\" />")
            // Also check what happens if a value XML file also contains the same ID.
            .addResource(
                "values/ids.xml",
                AndroidDataBuilder.ResourceType.VALUE,
                "<item name=\"MyTextView\" type=\"id\"/>",
                "<item name=\"OtherId\" type=\"id\"/>")
            .addResource(
                "values/strings.xml",
                AndroidDataBuilder.ResourceType.VALUE,
                "<string name=\"walrus\">I has a bucket</string>")
            .createManifest("AndroidManifest.xml", "com.carroll.lewis", "")
            .buildParsed();
    UnwrittenMergedAndroidData expected =
        UnwrittenMergedAndroidData.of(
            manifest,
            direct,
            ParsedAndroidDataBuilder.empty());
    expected.serializeTo(serializer);
    serializer.flushTo(binaryPath);

    AndroidDataDeserializer deserializer = AndroidParsedDataDeserializer.create();
    TestMapConsumer<DataResource> overwriting = TestMapConsumer.ofResources();
    TestMapConsumer<DataResource> combining = TestMapConsumer.ofResources();
    deserializer.read(
        binaryPath,
        KeyValueConsumers.of(
            overwriting,
            combining,
            null // assets
        ));
    assertThat(overwriting).isEqualTo(expected.getPrimary().getOverwritingResources());
    assertThat(combining).isEqualTo(expected.getPrimary().getCombiningResources());
  }

  @Test
  public void serialize() throws Exception {
    Path binaryPath = fs.getPath("out.bin");
    AndroidDataSerializer serializer = AndroidDataSerializer.create();
    UnwrittenMergedAndroidData expected =
        UnwrittenMergedAndroidData.of(
            manifest,
            ParsedAndroidDataBuilder.buildOn(source, fqnFactory)
                .overwritable(
                    file("layout/banker").source("layout/banker.xml"),
                    xml("<resources>/foo").source("values/ids.xml")
                        .value(ResourcesAttribute.of(
                            fqnFactory.parse("<resources>/foo"), "foo", "fooVal")))
                .combining(
                    xml("id/snark").source("values/ids.xml").value(IdXmlResourceValue.of()))
                .assets(file().source("hunting/of/the/boojum"))
                .build(),
            ParsedAndroidDataBuilder.buildOn(source, fqnFactory)
                .overwritable(file("layout/butcher").source("layout/butcher.xml"))
                .combining(
                    xml("id/snark").source("values/ids.xml").value(IdXmlResourceValue.of()))
                .assets(file().source("hunting/of/the/snark"))
                .build());
    expected.serializeTo(serializer);
    serializer.flushTo(binaryPath);

    KeyValueConsumers primary =
        KeyValueConsumers.of(
            TestMapConsumer.ofResources(), // overwriting
            TestMapConsumer.ofResources(), // combining
            TestMapConsumer.ofAssets() // assets
            );

    AndroidDataDeserializer deserializer = AndroidParsedDataDeserializer.create();
    deserializer.read(binaryPath, primary);
    assertThat(primary.overwritingConsumer)
        .isEqualTo(expected.getPrimary().getOverwritingResources());
    assertThat(primary.combiningConsumer).isEqualTo(expected.getPrimary().getCombiningResources());
    assertThat(primary.assetConsumer).isEqualTo(expected.getPrimary().getAssets());
  }

  @Test
  public void testDeserializeMissing() throws Exception {
    Path binaryPath = fs.getPath("out.bin");
    AndroidDataSerializer serializer = AndroidDataSerializer.create();
    UnwrittenMergedAndroidData expected =
        UnwrittenMergedAndroidData.of(
            manifest,
            ParsedAndroidDataBuilder.buildOn(source, fqnFactory)
                .overwritable(
                    file("layout/banker").source("layout/banker.xml"),
                    xml("<resources>/foo").source("values/ids.xml")
                        .value(ResourcesAttribute.of(
                            fqnFactory.parse("<resources>/foo"), "foo", "fooVal")))
                .combining(
                    xml("id/snark").source("values/ids.xml").value(IdXmlResourceValue.of()))
                .assets(file().source("hunting/of/the/boojum"))
                .build(),
            ParsedAndroidDataBuilder.buildOn(source, fqnFactory)
                .overwritable(file("layout/butcher").source("layout/butcher.xml"))
                .combining(
                    xml("id/snark").source("values/ids.xml").value(IdXmlResourceValue.of()))
                .assets(file().source("hunting/of/the/snark"))
                .build());
    expected.serializeTo(serializer);
    serializer.flushTo(binaryPath);

    AndroidDataDeserializer deserializer =
        AndroidParsedDataDeserializer.withFilteredResources(
            ImmutableList.of("the/boojum", "values/ids.xml", "layout/banker.xml"));

    KeyValueConsumers primary =
        KeyValueConsumers.of(
            TestMapConsumer.ofResources(), // overwriting
            TestMapConsumer.ofResources(), // combining
            null // assets
            );

    deserializer.read(binaryPath, primary);
    assertThat(primary.overwritingConsumer).isEqualTo(Collections.emptyMap());
    assertThat(primary.combiningConsumer).isEqualTo(Collections.emptyMap());
  }

  @Test
  public void testCompiledDataDeserializerCreation() {
    AndroidCompiledDataDeserializer deserializer =
        AndroidCompiledDataDeserializer.create(/* includeFileContentsForValidation= */ false);
    assertThat(deserializer).isNotNull();
    AndroidCompiledDataDeserializer validatingDeserializer =
        AndroidCompiledDataDeserializer.create(/* includeFileContentsForValidation= */ true);
    assertThat(validatingDeserializer).isNotNull();
  }

  @Test
  public void testNormalizedResourceDirectory_blazePrefixStripped() {
    assertThat(
            AndroidCompiledDataDeserializer.getNormalizedResourceDirectory(
                Paths.get("blaze-out/k8-opt/bin/com/example/res/values/strings.xml")))
        .isEqualTo(Paths.get("com/example/res"));
    assertThat(
            AndroidCompiledDataDeserializer.getNormalizedResourceDirectory(
                Paths.get("blaze-out/bin/res/values/strings.xml")))
        .isEqualTo(Paths.get("blaze-out/bin/res"));
  }

  @Test
  public void testNormalizedResourceDirectory_nonBlazePathPreserved() {
    assertThat(
            AndroidCompiledDataDeserializer.getNormalizedResourceDirectory(
                Paths.get("com/example/res/values/strings.xml")))
        .isEqualTo(Paths.get("com/example/res"));
    assertThat(
            AndroidCompiledDataDeserializer.getNormalizedResourceDirectory(
                Paths.get("a/b/c/d/res/values/strings.xml")))
        .isEqualTo(Paths.get("a/b/c/d/res"));
  }

  @Test
  public void testNormalizedResourceDirectory_shortPathsAndNulls() {
    assertThat(
            AndroidCompiledDataDeserializer.getNormalizedResourceDirectory(
                Paths.get("values/strings.xml")))
        .isNull();
    assertThat(AndroidCompiledDataDeserializer.getNormalizedResourceDirectory((Path) null))
        .isNull();
    assertThat(AndroidCompiledDataDeserializer.getNormalizedResourceDirectory((String) null))
        .isNull();
    assertThat(AndroidCompiledDataDeserializer.getNormalizedResourceDirectory("")).isNull();
  }

  @Test
  public void testConvertToQualifiers_defaultInstance() {
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(Configuration.getDefaultInstance()))
        .isEmpty();
  }

  @Test
  public void testConvertToQualifiers_individualQualifiers() {
    // MCC & MNC
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder().setMcc(310).setMnc(260).build()))
        .containsAtLeast("mcc310", "mnc260");
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder().setMnc(0xffff).build()))
        .containsExactly("mnc000");

    // Locale
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder().setLocale("en-US").build()))
        .containsExactly("en-rUS");

    // Layout Direction
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder()
                    .setLayoutDirection(Configuration.LayoutDirection.LAYOUT_DIRECTION_LTR)
                    .build()))
        .containsExactly("ldltr");
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder()
                    .setLayoutDirection(Configuration.LayoutDirection.LAYOUT_DIRECTION_RTL)
                    .build()))
        .containsExactly("ldrtl");

    // Dimensions & Smallest Screen Width
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder().setSmallestScreenWidthDp(600).build()))
        .containsExactly("sw600dp");
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder().setScreenWidthDp(400).setScreenHeightDp(600).build()))
        .containsAtLeast("w400dp", "h600dp");
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder().setScreenWidth(1024).setScreenHeight(768).build()))
        .containsExactly("1024x768");

    // Screen Layout Size & Long
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder()
                    .setScreenLayoutSize(ScreenLayoutSize.SCREEN_LAYOUT_SIZE_LARGE)
                    .setScreenLayoutLong(ScreenLayoutLong.SCREEN_LAYOUT_LONG_LONG)
                    .build()))
        .containsAtLeast("large", "long");

    // Screen Round & Orientation
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder()
                    .setScreenRound(ScreenRound.SCREEN_ROUND_ROUND)
                    .setOrientation(Orientation.ORIENTATION_PORT)
                    .build()))
        .containsAtLeast("round", "port");

    // UI Mode & Night Mode
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder()
                    .setUiModeType(UiModeType.UI_MODE_TYPE_TELEVISION)
                    .setUiModeNight(UiModeNight.UI_MODE_NIGHT_NIGHT)
                    .build()))
        .containsAtLeast("television", "night");

    // Density
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder().setDensity(320).build()))
        .containsExactly("xhdpi");

    // Touchscreen & Keyboard
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder()
                    .setTouchscreen(Touchscreen.TOUCHSCREEN_FINGER)
                    .setKeysHidden(KeysHidden.KEYS_HIDDEN_KEYSEXPOSED)
                    .setKeyboard(Configuration.Keyboard.KEYBOARD_QWERTY)
                    .build()))
        .containsAtLeast("finger", "keysexposed", "qwerty");

    // Navigation & NavHidden
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder()
                    .setNavHidden(NavHidden.NAV_HIDDEN_NAVEXPOSED)
                    .setNavigation(Configuration.Navigation.NAVIGATION_DPAD)
                    .build()))
        .containsAtLeast("navexposed", "dpad");

    // SdkVersion
    assertThat(
            AndroidCompiledDataDeserializer.convertToQualifiers(
                Configuration.newBuilder().setSdkVersion(28).build()))
        .containsExactly("v28");
  }

  @Test
  public void testConvertToQualifiers_cachedLookup() {
    Configuration config =
        Configuration.newBuilder().setMcc(310).setLocale("fr-FR").setSdkVersion(30).build();
    ImmutableList<String> first = AndroidCompiledDataDeserializer.convertToQualifiers(config);
    ImmutableList<String> second = AndroidCompiledDataDeserializer.convertToQualifiers(config);
    assertThat(first).containsAtLeast("mcc310", "fr-rFR", "v30");
    assertThat(second).isSameInstanceAs(first);
  }

  private static class TestMapConsumer<T extends DataValue>
      implements ParsedAndroidData.KeyValueConsumer<DataKey, T>, Map<DataKey, T> {

    Map<DataKey, T> target;

    static TestMapConsumer<DataAsset> ofAssets() {
      return new TestMapConsumer<>(new HashMap<DataKey, DataAsset>());
    }

    static TestMapConsumer<DataResource> ofResources() {
      return new TestMapConsumer<>(new HashMap<DataKey, DataResource>());
    }

    private TestMapConsumer(Map<DataKey, T> target) {
      this.target = target;
    }

    @Override
    public void accept(DataKey key, T value) {
      target.put(key, value);
    }

    @Override
    public int size() {
      return target.size();
    }

    @Override
    public boolean isEmpty() {
      return target.isEmpty();
    }

    @Override
    public boolean containsKey(Object key) {
      return target.containsKey(key);
    }

    @Override
    public boolean containsValue(Object value) {
      return target.containsValue(value);
    }

    @Override
    public T get(Object key) {
      return target.get(key);
    }

    @Override
    public T put(DataKey key, T value) {
      return target.put(key, value);
    }

    @Override
    public T remove(Object key) {
      return target.remove(key);
    }

    @Override
    public void putAll(Map<? extends DataKey, ? extends T> m) {
      target.putAll(m);
    }

    @Override
    public void clear() {
      target.clear();
    }

    @Override
    public Set<DataKey> keySet() {
      return target.keySet();
    }

    @Override
    public Collection<T> values() {
      return target.values();
    }

    @Override
    public Set<Entry<DataKey, T>> entrySet() {
      return target.entrySet();
    }

    @Override
    public boolean equals(Object o) {
      return target.equals(o);
    }

    @Override
    public int hashCode() {
      return target.hashCode();
    }

    @Override
    public String toString() {
      return MoreObjects.toStringHelper(this).add("target", target).toString();
    }
  }
}
