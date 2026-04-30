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
import com.google.common.collect.ImmutableList;
import com.google.common.collect.Interner;
import com.google.common.collect.Interners;
import java.util.HashSet;

/**
 * Helper to track how many unique field and method references we've seen in a given set of .dex
 * files.
 */
class DexLimitTracker {

  private static final Interner<String> interner = Interners.newWeakInterner();

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
    track(new DexTrackerInfo(dexFile));
  }

  public void track(DexTrackerInfo info) {
    fieldsSeen.addAll(info.fields);
    methodsSeen.addAll(info.methods);
    typesSeen.addAll(info.types);
  }

  static class DexTrackerInfo {
    final ImmutableList<String> fields;
    final ImmutableList<String> methods;
    final ImmutableList<String> types;

    DexTrackerInfo(Dex dexFile) {
      int fieldCount = dexFile.fieldIds().size();
      ImmutableList.Builder<String> fieldsBuilder =
          ImmutableList.builderWithExpectedSize(fieldCount);
      for (int fieldIndex = 0; fieldIndex < fieldCount; ++fieldIndex) {
        fieldsBuilder.add(fieldSignature(dexFile, fieldIndex));
      }
      fields = fieldsBuilder.build();

      int methodCount = dexFile.methodIds().size();
      ImmutableList.Builder<String> methodsBuilder =
          ImmutableList.builderWithExpectedSize(methodCount);
      for (int methodIndex = 0; methodIndex < methodCount; ++methodIndex) {
        methodsBuilder.add(methodSignature(dexFile, methodIndex));
      }
      methods = methodsBuilder.build();

      int typeCount = dexFile.typeIds().size();
      ImmutableList.Builder<String> typesBuilder = ImmutableList.builderWithExpectedSize(typeCount);
      for (int typeIndex = 0; typeIndex < typeCount; ++typeIndex) {
        typesBuilder.add(typeName(dexFile, typeIndex));
      }
      types = typesBuilder.build();
    }
  }

  private static String typeName(Dex dex, int typeIndex) {
    return interner.intern(dex.typeNames().get(typeIndex));
  }

  private static String fieldSignature(Dex dex, int fieldIndex) {
    FieldId field = dex.fieldIds().get(fieldIndex);
    String name = dex.strings().get(field.getNameIndex());
    String declaringClass = typeName(dex, field.getDeclaringClassIndex());
    String type = typeName(dex, field.getTypeIndex());
    return interner.intern(declaringClass + "." + name + ":" + type);
  }

  private static String methodSignature(Dex dex, int methodIndex) {
    MethodId method = dex.methodIds().get(methodIndex);
    ProtoId proto = dex.protoIds().get(method.getProtoIndex());
    String name = dex.strings().get(method.getNameIndex());
    String declaringClass = typeName(dex, method.getDeclaringClassIndex());
    String returnType = typeName(dex, proto.getReturnTypeIndex());
    TypeList parameterTypeIndices = dex.readTypeList(proto.getParametersOffset());
    StringBuilder parameterTypes = new StringBuilder();
    for (short parameterTypeIndex : parameterTypeIndices.getTypes()) {
      parameterTypes.append(typeName(dex, parameterTypeIndex & 0xFFFF));
    }
    return interner.intern(
        declaringClass + "." + name + ":" + returnType + "(" + parameterTypes + ")");
  }
}
