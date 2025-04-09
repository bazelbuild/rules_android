// Copyright 2025 The Bazel Authors. All rights reserved.
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

/**
 * Implements the 32-bit variant of the FNV-1a hash algorithm. This is a Java port of the Golang FNV
 * hash implementation for legacy compatibility with ak dex. See
 * https://en.wikipedia.org/wiki/Fowler%E2%80%93Noll%E2%80%93Vo_hash_function.
 */
final class Fnv1a32bHash {
  // Note: `long` is used here, despite the 32-bit datatype, since Java doesn't support unsigned
  // integers, and the sums generated in the hash may write to the most significant bit.
  private static final long OFFSET = 2166136261L;
  private static final long PRIME = 16777619;

  private Fnv1a32bHash() {}

  public static long hash(byte[] bytes) {
    long sum = OFFSET;
    for (byte b : bytes) {
      // Truncate the sum to 32 bits.
      sum = (sum * PRIME) & 0xffffffff;
      sum = sum ^ b;
    }

    return sum;
  }
}
