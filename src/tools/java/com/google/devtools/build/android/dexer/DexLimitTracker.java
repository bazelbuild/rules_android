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
package com.google.devtools.build.android.dexer;

import com.android.dex.Dex;
import com.android.dex.FieldId;
import com.android.dex.MethodId;
import com.android.dex.ProtoId;
import com.android.dex.TypeList;
import com.google.common.collect.Interner;
import com.google.common.collect.Interners;
import java.util.Collections;
import java.util.HashSet;

/**
 * Helper to track how many unique field and method references we've seen in a given set of .dex
 * files.
 */
class DexLimitTracker {

  private static final ThreadLocal<Interner<String>> threadLocalInterner =
      ThreadLocal.withInitial(Interners::newWeakInterner);

  private final HashSet<String> fieldsSeen = new HashSet<>();
  private final HashSet<String> methodsSeen = new HashSet<>();
  private final HashSet<String> typesSeen = new HashSet<>();
  private final int maxNumberOfIdxPerDex;

  public DexLimitTracker(int maxNumberOfIdxPerDex) {
    this.maxNumberOfIdxPerDex = maxNumberOfIdxPerDex;
  }

  /**
   * Returns whether we're within limits.
   *
   * @return {@code true} if method, field or type references are outside limits, {@code false} if
   *     all are within limits.
   */
  public boolean outsideLimits() {
    return fieldsSeen.size() > maxNumberOfIdxPerDex
        || methodsSeen.size() > maxNumberOfIdxPerDex
        || typesSeen.size() > maxNumberOfIdxPerDex;
  }

  public void clear() {
    fieldsSeen.clear();
    methodsSeen.clear();
    typesSeen.clear();
  }

  public void track(Dex dexFile) {
    track(DexTrackerInfo.create(dexFile));
  }

  public void track(DexTrackerInfo info) {
    Collections.addAll(fieldsSeen, info.fields);
    Collections.addAll(methodsSeen, info.methods);
    Collections.addAll(typesSeen, info.types);
  }

  static final class DexTrackerInfo {
    final String[] fields;
    final String[] methods;
    final String[] types;

    DexTrackerInfo(String[] fields, String[] methods, String[] types) {
      this.fields = fields;
      this.methods = methods;
      this.types = types;
    }

    static DexTrackerInfo create(Dex dexFile) {
      int typeCount = dexFile.typeIds().size();
      String[] types = new String[typeCount];
      for (int typeIndex = 0; typeIndex < typeCount; ++typeIndex) {
        types[typeIndex] = typeName(dexFile, typeIndex);
      }

      int fieldCount = dexFile.fieldIds().size();
      String[] fields = new String[fieldCount];
      for (int fieldIndex = 0; fieldIndex < fieldCount; ++fieldIndex) {
        fields[fieldIndex] = fieldSignature(dexFile, fieldIndex, types);
      }

      int methodCount = dexFile.methodIds().size();
      String[] methods = new String[methodCount];
      for (int methodIndex = 0; methodIndex < methodCount; ++methodIndex) {
        methods[methodIndex] = methodSignature(dexFile, methodIndex, types);
      }

      return new DexTrackerInfo(fields, methods, types);
    }
  }

  private static String typeName(Dex dex, int typeIndex) {
    return threadLocalInterner.get().intern(dex.typeNames().get(typeIndex));
  }

  private static String fieldSignature(Dex dex, int fieldIndex, String[] typeCache) {
    FieldId field = dex.fieldIds().get(fieldIndex);
    String name = dex.strings().get(field.getNameIndex());
    String declaringClass = typeCache[field.getDeclaringClassIndex()];
    String type = typeCache[field.getTypeIndex()];
    return threadLocalInterner.get().intern(declaringClass + "." + name + ":" + type);
  }

  private static String methodSignature(Dex dex, int methodIndex, String[] typeCache) {
    MethodId method = dex.methodIds().get(methodIndex);
    ProtoId proto = dex.protoIds().get(method.getProtoIndex());
    String name = dex.strings().get(method.getNameIndex());
    String declaringClass = typeCache[method.getDeclaringClassIndex()];
    String returnType = typeCache[proto.getReturnTypeIndex()];
    TypeList parameterTypeIndices = dex.readTypeList(proto.getParametersOffset());
    StringBuilder parameterTypes = new StringBuilder();
    for (short parameterTypeIndex : parameterTypeIndices.getTypes()) {
      parameterTypes.append(typeCache[parameterTypeIndex & 0xFFFF]);
    }
    return threadLocalInterner
        .get()
        .intern(declaringClass + "." + name + ":" + returnType + "(" + parameterTypes + ")");
  }
}
