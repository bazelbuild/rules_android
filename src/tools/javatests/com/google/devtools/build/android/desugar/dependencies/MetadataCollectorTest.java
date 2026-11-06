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
package com.google.devtools.build.android.desugar.dependencies;

import static com.google.common.collect.ImmutableList.toImmutableList;
import static com.google.common.truth.Truth.assertThat;
import static java.nio.charset.StandardCharsets.UTF_8;

import com.google.devtools.build.android.desugar.proto.DesugarDeps;
import com.google.devtools.build.android.desugar.proto.DesugarDeps.DesugarDepsInfo;
import com.google.devtools.build.android.desugar.proto.DesugarDeps.InterfaceDetails;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.util.Arrays;
import org.junit.Test;
import org.junit.experimental.runners.Enclosed;
import org.junit.runner.RunWith;
import org.junit.runners.JUnit4;

/** Unit tests for {@link MetadataCollector}. */
@RunWith(Enclosed.class)
public abstract class MetadataCollectorTest {

  private final boolean emitJson;

  protected MetadataCollectorTest(boolean emitJson) {
    this.emitJson = emitJson;
  }

  /** Tests for {@link MetadataCollector} emitting protobuf metadata. */
  @RunWith(JUnit4.class)
  public static class ProtoMetadataCollectorTest extends MetadataCollectorTest {

    public ProtoMetadataCollectorTest() {
      super(/* emitJson= */ false);
    }

    @Override
    @SuppressWarnings("ProtoParseWithRegistry")
    protected DesugarDepsInfo extractProto(MetadataCollector collector) throws Exception {
      return DesugarDepsInfo.parseFrom(collector.toByteArray());
    }
  }

  /** Tests for {@link MetadataCollector} emitting JSON metadata. */
  @RunWith(JUnit4.class)
  public static class JsonMetadataCollectorTest extends MetadataCollectorTest {

    public JsonMetadataCollectorTest() {
      super(/* emitJson= */ true);
    }

    @Override
    protected DesugarDepsInfo extractProto(MetadataCollector collector) {
      JsonObject root =
          JsonParser.parseString(new String(collector.toByteArray(), UTF_8)).getAsJsonObject();
      DesugarDepsInfo.Builder info = DesugarDepsInfo.newBuilder();
      if (root.has("assume_present")) {
        for (JsonElement element : root.getAsJsonArray("assume_present")) {
          JsonObject dep = element.getAsJsonObject();
          info.addAssumePresent(
              dependency(dep.get("origin").getAsString(), dep.get("target").getAsString()));
        }
      }
      if (root.has("missing_interface")) {
        for (JsonElement element : root.getAsJsonArray("missing_interface")) {
          JsonObject dep = element.getAsJsonObject();
          info.addMissingInterface(
              dependency(dep.get("origin").getAsString(), dep.get("target").getAsString()));
        }
      }
      if (root.has("interface_with_supertypes")) {
        for (JsonElement element : root.getAsJsonArray("interface_with_supertypes")) {
          JsonObject details = element.getAsJsonObject();
          String[] extendedInterfaces =
              details.getAsJsonArray("extended_interface").asList().stream()
                  .map(JsonElement::getAsString)
                  .toArray(String[]::new);
          info.addInterfaceWithSupertypes(
              interfaceDetails(details.get("origin").getAsString(), extendedInterfaces));
        }
      }
      if (root.has("interface_with_companion")) {
        for (JsonElement element : root.getAsJsonArray("interface_with_companion")) {
          JsonObject companion = element.getAsJsonObject();
          info.addInterfaceWithCompanion(
              interfaceWithCompanion(
                  companion.get("origin").getAsString(),
                  companion.get("num_default_methods").getAsInt()));
        }
      }
      return info.build();
    }
  }

  @Test
  public void testEmptyAvoidsOutput() {
    assertThat(createCollector(false).toByteArray()).isNull();
  }

  @Test
  public void testAssumeCompanionClass() throws Exception {
    MetadataCollector collector = createCollector(false);
    collector.assumeCompanionClass("a", "b$$CC");
    collector.assumeCompanionClass("b", "b$$CC");
    collector.assumeCompanionClass("a", "a$$CC");

    DesugarDepsInfo info = extractProto(collector);

    assertThat(info.getAssumePresentList())
        .containsExactly(
            dependency("a", "a$$CC"), dependency("a", "b$$CC"), dependency("b", "b$$CC"));
  }

  @Test
  public void testMissingImplementedInterface() throws Exception {
    MetadataCollector collector = createCollector(true);
    collector.missingImplementedInterface("a", "b");
    collector.missingImplementedInterface("c", "b");
    collector.missingImplementedInterface("a", "c");

    DesugarDepsInfo info = extractProto(collector);
    assertThat(info.getMissingInterfaceList().get(0)).isEqualTo(dependency("a", "b"));
    assertThat(info.getMissingInterfaceList().get(1)).isEqualTo(dependency("a", "c"));
    assertThat(info.getMissingInterfaceList().get(2)).isEqualTo(dependency("c", "b"));
  }

  @Test
  public void testRecordExtendedInterfaces() throws Exception {
    MetadataCollector collector = createCollector(false);
    collector.recordExtendedInterfaces("c", "d");
    collector.recordExtendedInterfaces("a", "c", "b");
    collector.recordExtendedInterfaces("b");

    DesugarDepsInfo info = extractProto(collector);

    assertThat(info.getInterfaceWithSupertypesList().get(0))
        .isEqualTo(interfaceDetails("a", "b", "c"));
    assertThat(info.getInterfaceWithSupertypesList().get(0).getExtendedInterfaceList().get(0))
        .isEqualTo(wrapType("b"));
    assertThat(info.getInterfaceWithSupertypesList().get(0).getExtendedInterfaceList().get(1))
        .isEqualTo(wrapType("c"));

    assertThat(info.getInterfaceWithSupertypesList().get(1)).isEqualTo(interfaceDetails("c", "d"));
  }

  @Test
  public void testRecordDefaultMethods() throws Exception {
    MetadataCollector collector = createCollector(false);
    collector.recordDefaultMethods("b", 1);
    collector.recordDefaultMethods("a", 0);

    DesugarDepsInfo info = extractProto(collector);
    assertThat(info.getInterfaceWithCompanionList().get(0))
        .isEqualTo(interfaceWithCompanion("a", 0));
    assertThat(info.getInterfaceWithCompanionList().get(1))
        .isEqualTo(interfaceWithCompanion("b", 1));
  }

  private MetadataCollector createCollector(boolean tolerateMissingDeps) {
    return new MetadataCollector(tolerateMissingDeps, emitJson);
  }

  private static DesugarDeps.InterfaceWithCompanion interfaceWithCompanion(
      String origin, int count) {
    return DesugarDeps.InterfaceWithCompanion.newBuilder()
        .setOrigin(wrapType(origin))
        .setNumDefaultMethods(count)
        .build();
  }

  private static DesugarDeps.InterfaceDetails interfaceDetails(
      String originName, String... interfaces) {
    return InterfaceDetails.newBuilder()
        .setOrigin(wrapType(originName))
        .addAllExtendedInterface(
            Arrays.stream(interfaces)
                .map(MetadataCollectorTest::wrapType)
                .collect(toImmutableList()))
        .build();
  }

  private static DesugarDeps.Dependency dependency(String origin, String target) {
    return DesugarDeps.Dependency.newBuilder()
        .setOrigin(wrapType(origin))
        .setTarget(wrapType(target))
        .build();
  }

  private static DesugarDeps.Type wrapType(String name) {
    return DesugarDeps.Type.newBuilder().setBinaryName(name).build();
  }

  protected abstract DesugarDepsInfo extractProto(MetadataCollector collector) throws Exception;
}
