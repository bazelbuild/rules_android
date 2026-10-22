// Copyright 2026 The Bazel Authors. All rights reserved.
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
package com.google.devtools.build.android.r8.desugar;

import com.android.tools.r8.ArchiveClassFileProvider;
import com.android.tools.r8.ClassFileResourceProvider;
import com.android.tools.r8.DiagnosticsHandler;
import com.android.tools.r8.ProgramResource;
import com.android.tools.r8.ProgramResource.Kind;
import com.android.tools.r8.origin.ArchiveEntryOrigin;
import com.android.tools.r8.origin.PathOrigin;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableSet;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Path;
import java.util.function.Consumer;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import javax.annotation.Nullable;
import javax.annotation.concurrent.GuardedBy;

/**
 * Class file provider for a classpath (or library) archive, which opens the archive only when a
 * class is first read from it, and closes it on {@link #finished}.
 *
 * <p>Classpaths can contain tens of thousands of archives of which only a few are read from, and
 * keeping all of them open as {@link ZipFile}s takes a lot of memory. Reading classes through a
 * plain {@link ZipFile} also avoids building {@link ArchiveClassFileProvider}'s descriptor set
 * again.
 */
public final class LazyArchiveClassFileProvider implements ClassFileResourceProvider {
  private static final String CLASS_EXTENSION = ".class";

  private final Path archive;
  private final ImmutableList<String> descriptors;

  @GuardedBy("this")
  private ImmutableSet<String> descriptorSet;

  @GuardedBy("this")
  private ZipFile zipFile;

  public LazyArchiveClassFileProvider(Path archive) throws IOException {
    this.archive = archive;
    try (ArchiveClassFileProvider indexer = new ArchiveClassFileProvider(archive)) {
      descriptors = ImmutableList.copyOf(indexer.getClassDescriptors());
    }
  }

  /** Returns the descriptors of the classes in the archive, which is cheaper than a set. */
  public ImmutableList<String> getClassDescriptorList() {
    return descriptors;
  }

  @Override
  public synchronized ImmutableSet<String> getClassDescriptors() {
    if (descriptorSet == null) {
      descriptorSet = ImmutableSet.copyOf(descriptors);
    }
    return descriptorSet;
  }

  @Override
  @Nullable
  public ProgramResource getProgramResource(String descriptor) {
    String entryName = descriptor.substring(1, descriptor.length() - 1) + CLASS_EXTENSION;
    // Leave out the entries which ArchiveClassFileProvider leaves out of the index (the same
    // checks as R8's ZipUtils.isClassFile), rather than checking the descriptor set, so that the
    // set is not built just to read a class.
    if (entryName.endsWith("module-info.class")
        || entryName.startsWith("META-INF")
        || entryName.startsWith("/META-INF")) {
      return null;
    }
    try {
      ZipFile zipFile = getZipFile();
      ZipEntry entry = zipFile.getEntry(entryName);
      if (entry == null) {
        return null;
      }
      byte[] bytes;
      try (InputStream in = zipFile.getInputStream(entry)) {
        bytes = in.readAllBytes();
      }
      return ProgramResource.fromBytes(
          new ArchiveEntryOrigin(entryName, new PathOrigin(archive)),
          Kind.CF,
          bytes,
          ImmutableSet.of(descriptor));
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to read " + entryName + " from " + archive, e);
    }
  }

  @Override
  public void getProgramResources(Consumer<ProgramResource> consumer) {
    for (String descriptor : descriptors) {
      consumer.accept(getProgramResource(descriptor));
    }
  }

  private synchronized ZipFile getZipFile() throws IOException {
    if (zipFile == null) {
      zipFile = new ZipFile(archive.toFile());
    }
    return zipFile;
  }

  /** Closes the archive, which is opened again if another class is read from it. */
  @Override
  public synchronized void finished(DiagnosticsHandler handler) throws IOException {
    if (zipFile != null) {
      zipFile.close();
      zipFile = null;
    }
  }
}
