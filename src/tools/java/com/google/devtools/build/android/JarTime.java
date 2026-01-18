// Copyright 2015 The Bazel Authors. All rights reserved.
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

import java.time.LocalDateTime;

/** Jar timestamp normalization. */
public final class JarTime {
  /**
   * Normalize timestamps to 2010-1-1.
   *
   * <p>The ZIP format uses MS-DOS timestamps (see <a
   * href="https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT">APPNOTE.TXT</a>) which use
   * 1980-1-1 as the epoch. To work around this, {@link ZipEntry} uses portability-reducing ZIP
   * extensions to store pre-1980 timestamps, which can occasionally <a
   * href="https://bugs.openjdk.java.net/browse/JDK-8246129>cause</a> <a
   * href="https://openjdk.markmail.org/thread/wzw7zfilk5j7uzqk>issues</a>. For that reason, using a
   * fixed post-1980 timestamp is preferred. At Google, the timestamp of 2010-1-1 is used by
   * convention in deterministic jar archives.
   */
  public static final LocalDateTime DEFAULT_TIMESTAMP = LocalDateTime.of(2010, 1, 1, 0, 0, 0);

  private JarTime() {}
}
