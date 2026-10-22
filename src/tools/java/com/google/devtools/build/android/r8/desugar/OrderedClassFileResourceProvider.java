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
package com.google.devtools.build.android.r8.desugar;

import com.android.tools.r8.ClassFileResourceProvider;
import com.android.tools.r8.DiagnosticsHandler;
import com.android.tools.r8.ProgramResource;
import com.google.common.base.Throwables;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.Maps;
import java.io.IOException;
import java.util.Collection;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import javax.annotation.Nullable;

/**
 * Classpath provider which will de-dupe duplicate classes from several providers. For any defined
 * class the definition from the first provider defining the class is used.
 */
public class OrderedClassFileResourceProvider implements ClassFileResourceProvider {
  private final ImmutableList<ClassFileResourceProvider> classfileProviders;
  // Built in the background, as D8 does quite some work before it first looks at the classpath.
  private final CompletableFuture<Map<String, ClassFileResourceProvider>> descriptorToProvider;

  public OrderedClassFileResourceProvider(
      ImmutableList<ClassFileResourceProvider> bootclasspathProviders,
      ImmutableList<ClassFileResourceProvider> classfileProviders) {
    this.classfileProviders = classfileProviders;
    // Collected up front, as D8 also uses the bootclasspath providers, which are not thread-safe.
    Set<String> bootclasspathDescriptors = new HashSet<>();
    bootclasspathProviders.forEach(p -> bootclasspathDescriptors.addAll(getDescriptors(p)));
    descriptorToProvider =
        CompletableFuture.supplyAsync(
            () -> buildDescriptorToProvider(bootclasspathDescriptors, classfileProviders));
  }

  private static Map<String, ClassFileResourceProvider> buildDescriptorToProvider(
      Set<String> bootclasspathDescriptors,
      ImmutableList<ClassFileResourceProvider> classfileProviders) {
    int size = 0;
    for (ClassFileResourceProvider provider : classfileProviders) {
      size += getDescriptors(provider).size();
    }
    Map<String, ClassFileResourceProvider> descriptorToProvider =
        Maps.newHashMapWithExpectedSize(size);
    for (ClassFileResourceProvider provider : classfileProviders) {
      // Collect all descriptors provided and the first provider providing each.
      for (String descriptor : getDescriptors(provider)) {
        // Pick first definition of classpath class and filter out platform classes
        // from classpath if present.
        if (!bootclasspathDescriptors.contains(descriptor)) {
          descriptorToProvider.putIfAbsent(descriptor, provider);
        }
      }
    }
    return descriptorToProvider;
  }

  private static Collection<String> getDescriptors(ClassFileResourceProvider provider) {
    return provider instanceof LazyArchiveClassFileProvider lazyProvider
        ? lazyProvider.getClassDescriptorList()
        : provider.getClassDescriptors();
  }

  private Map<String, ClassFileResourceProvider> getDescriptorToProvider() {
    try {
      return descriptorToProvider.join();
    } catch (CompletionException e) {
      // Throw what building the map threw, as if it had not been built in the background.
      Throwables.throwIfUnchecked(e.getCause());
      throw e;
    }
  }

  @Override
  public Set<String> getClassDescriptors() {
    return getDescriptorToProvider().keySet();
  }

  @Override
  @Nullable
  public ProgramResource getProgramResource(String descriptor) {
    ClassFileResourceProvider provider = getDescriptorToProvider().get(descriptor);
    return provider != null ? provider.getProgramResource(descriptor) : null;
  }

  /**
   * Signals the classpath providers that the compilation is done, so that they can close their
   * archives. The bootclasspath providers are passed to the compiler as library providers, which it
   * signals itself.
   */
  @Override
  public void finished(DiagnosticsHandler handler) throws IOException {
    // Wait for the background thread to stop reading from the providers. A failure there only
    // matters if the compiler looked up a class, which threw it, so don't throw it again here,
    // where it would replace the compiler's own exception.
    descriptorToProvider.exceptionally(e -> null).join();
    for (ClassFileResourceProvider provider : classfileProviders) {
      provider.finished(handler);
    }
  }
}
