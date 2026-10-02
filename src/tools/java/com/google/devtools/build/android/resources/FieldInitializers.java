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
package com.google.devtools.build.android.resources;

import com.android.resources.ResourceType;
import com.google.common.base.MoreObjects;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableListMultimap;
import com.google.common.collect.Maps;
import java.util.BitSet;
import java.util.Collection;
import java.util.Collections;
import java.util.EnumMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;
import java.util.function.Predicate;

/**
 * Represents a collection of resource symbols and values suitable for writing java sources and
 * classes.
 */
public class FieldInitializers
    implements Iterable<Map.Entry<ResourceType, Collection<FieldInitializer>>> {

  private final Map<ResourceType, Collection<FieldInitializer>> initializers;

  /** Lazily computed by {@link #fieldIndex}. */
  private Map<ResourceType, TypeIndex> fieldIndex;

  private FieldInitializers(Map<ResourceType, Collection<FieldInitializer>> initializers) {
    this.initializers = initializers;
  }

  /** Creates a {@link FieldInitializers} copying the contents from a {@link Map}. */
  public static FieldInitializers copyOf(
      Map<ResourceType, Collection<FieldInitializer>> initializers) {
    Map<ResourceType, Collection<FieldInitializer>> deeplyImmutableInitializers =
        initializers.entrySet().stream()
            .collect(
                ImmutableListMultimap.flatteningToImmutableListMultimap(
                    Map.Entry::getKey, entry -> entry.getValue().stream()))
            .asMap();

    return new FieldInitializers(deeplyImmutableInitializers);
  }

  public static FieldInitializers mergedFrom(Collection<FieldInitializers> toMerge) {
    final Map<ResourceType, Collection<FieldInitializer>> merged =
        new EnumMap<>(ResourceType.class);

    for (ResourceType resourceType : ResourceType.values()) {
      ImmutableList<FieldInitializer> fieldInitializers =
          toMerge.stream()
              .flatMap(
                  fis -> fis.initializers.getOrDefault(resourceType, ImmutableList.of()).stream())
              .filter(distinctByKey(FieldInitializer::getFieldName))
              .collect(ImmutableList.toImmutableList());

      if (!fieldInitializers.isEmpty()) {
        merged.put(resourceType, fieldInitializers);
      }
    }

    return copyOf(merged);
  }

  private static <T> Predicate<T> distinctByKey(Function<? super T, ?> keyExtractor) {
    Set<Object> seen = ConcurrentHashMap.newKeySet();
    return t -> seen.add(keyExtractor.apply(t));
  }

  public FieldInitializers filter(FieldInitializers fieldsToWrite) {
    return filter(ImmutableList.of(fieldsToWrite));
  }

  /**
   * Returns the subset of this instance's fields whose names appear in any of {@code
   * fieldsToWrite}, in this instance's order.
   */
  public FieldInitializers filter(Collection<FieldInitializers> fieldsToWrite) {
    Map<ResourceType, TypeIndex> index = fieldIndex();
    Map<ResourceType, BitSet> selectedByType = new EnumMap<>(ResourceType.class);
    for (FieldInitializers toWrite : fieldsToWrite) {
      for (Map.Entry<ResourceType, Collection<FieldInitializer>> entry :
          toWrite.initializers.entrySet()) {
        // Resource type may be missing if resource overriding eliminates resources at the binary
        // level, which were originally present at the library level.
        TypeIndex typeIndex = index.get(entry.getKey());
        if (typeIndex == null) {
          continue;
        }
        BitSet selected = selectedByType.computeIfAbsent(entry.getKey(), k -> new BitSet());
        for (FieldInitializer initializer : entry.getValue()) {
          Integer position = typeIndex.positions.get(initializer.getFieldName());
          if (position != null) {
            selected.set(position);
          }
        }
      }
    }
    final Map<ResourceType, Collection<FieldInitializer>> initializersToWrite =
        new EnumMap<>(ResourceType.class);
    for (Map.Entry<ResourceType, BitSet> entry : selectedByType.entrySet()) {
      BitSet selected = entry.getValue();
      if (selected.isEmpty()) {
        continue;
      }
      ImmutableList<FieldInitializer> fields = index.get(entry.getKey()).fields;
      ImmutableList.Builder<FieldInitializer> builder =
          ImmutableList.builderWithExpectedSize(selected.cardinality());
      for (int i = selected.nextSetBit(0); i >= 0; i = selected.nextSetBit(i + 1)) {
        builder.add(fields.get(i));
      }
      initializersToWrite.put(entry.getKey(), builder.build());
    }
    return new FieldInitializers(Collections.unmodifiableMap(initializersToWrite));
  }

  /** The fields of one resource type, with an index from field name to position. */
  private static final class TypeIndex {
    final ImmutableList<FieldInitializer> fields;
    final Map<String, Integer> positions;

    TypeIndex(Collection<FieldInitializer> fields) {
      this.fields = ImmutableList.copyOf(fields);
      this.positions = Maps.newHashMapWithExpectedSize(this.fields.size());
      for (int i = 0; i < this.fields.size(); i++) {
        positions.putIfAbsent(this.fields.get(i).getFieldName(), i);
      }
    }
  }

  /**
   * Returns a {@link TypeIndex} for each resource type. Built lazily, as it is only needed for
   * {@link #filter}. Field names are expected to be unique within a type (e.g. symbol tables loaded
   * from R.txt are deduped by name).
   */
  private synchronized Map<ResourceType, TypeIndex> fieldIndex() {
    if (fieldIndex == null) {
      Map<ResourceType, TypeIndex> index = new EnumMap<>(ResourceType.class);
      for (Map.Entry<ResourceType, Collection<FieldInitializer>> entry : initializers.entrySet()) {
        index.put(entry.getKey(), new TypeIndex(entry.getValue()));
      }
      fieldIndex = index;
    }
    return fieldIndex;
  }

  @Override
  public Iterator<Map.Entry<ResourceType, Collection<FieldInitializer>>> iterator() {
    return initializers.entrySet().iterator();
  }

  @Override
  public String toString() {
    return MoreObjects.toStringHelper(FieldInitializers.class)
        .add("initializers", initializers)
        .toString();
  }
}
