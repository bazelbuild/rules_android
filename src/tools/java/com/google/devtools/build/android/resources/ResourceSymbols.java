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

import static com.google.common.collect.ImmutableList.toImmutableList;

import com.android.SdkConstants;
import com.android.manifmerger.ManifestProvider;
import com.android.manifmerger.PlaceholderHandler;
import com.android.resources.ResourceType;
import com.android.utils.XmlUtils;
import com.google.common.base.Strings;
import com.google.common.base.Throwables;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.common.collect.LinkedHashMultimap;
import com.google.common.collect.Multimap;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.common.util.concurrent.ListeningExecutorService;
import com.google.common.util.concurrent.Uninterruptibles;
import com.google.devtools.build.android.DependencyInfo;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.logging.Logger;
import javax.annotation.Nullable;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;
import javax.xml.parsers.SAXParserFactory;
import org.xml.sax.Attributes;
import org.xml.sax.SAXException;
import org.xml.sax.helpers.DefaultHandler;

/** Encapsulates the logic for loading and writing resource symbols. */
public class ResourceSymbols {
  private static final Logger logger = Logger.getLogger(ResourceSymbols.class.getCanonicalName());

  /** Task to load and parse R.txt symbols */
  private static final class SymbolLoadingTask implements Callable<ResourceSymbols> {

    private final Path rTxtSymbols;

    SymbolLoadingTask(Path symbolFile) {
      this.rTxtSymbols = symbolFile;
    }

    @Override
    public ResourceSymbols call() throws Exception {
      List<String> lines = Files.readAllLines(rTxtSymbols, StandardCharsets.UTF_8);

      // NB: deduping by field name is working around a bug in R.txt generation!
      // TODO(b/140643407): read directly without having to dedup by field name
      final Map<ResourceType, List<FieldInitializer>> initializers =
          new EnumMap<>(ResourceType.class);

      for (int lineIndex = 1; lineIndex <= lines.size(); lineIndex++) {
        String line = null;
        try {
          line = lines.get(lineIndex - 1);

          // format is "<type> <class> <name> <value>"
          // don't want to split on space as value could contain spaces.
          int pos = line.indexOf(' ');
          String type = line.substring(0, pos);
          int pos2 = line.indexOf(' ', pos + 1);
          String className = line.substring(pos + 1, pos2);
          int pos3 = line.indexOf(' ', pos2 + 1);
          String name = line.substring(pos2 + 1, pos3);
          String value = line.substring(pos3 + 1);

          FieldInitializer initializer;
          if ("int".equals(type)) {
            initializer =
                IntFieldInitializer.of(DependencyInfo.UNKNOWN, Visibility.UNKNOWN, name, value);
          } else {
            initializer =
                IntArrayFieldInitializer.of(
                    DependencyInfo.UNKNOWN, Visibility.UNKNOWN, name, value);
          }

          initializers
              .computeIfAbsent(ResourceTypeEnum.get(className), k -> new ArrayList<>())
              .add(initializer);
        } catch (IndexOutOfBoundsException e) {
          String s =
              String.format(
                  "File format error reading %s\tline %d: '%s'",
                  rTxtSymbols.toString(), lineIndex, line);
          logger.severe(s);
          throw new IOException(s, e);
        }
      }

      ImmutableMap.Builder<ResourceType, Collection<FieldInitializer>> sortedInitializers =
          ImmutableMap.builderWithExpectedSize(initializers.size());
      for (Map.Entry<ResourceType, List<FieldInitializer>> entry : initializers.entrySet()) {
        sortedInitializers.put(entry.getKey(), sortAndDedupeByName(entry.getValue()));
      }
      return ResourceSymbols.from(FieldInitializers.copyOf(sortedInitializers.buildOrThrow()));
    }

    /**
     * Sorts by field name, keeping only the last occurrence of each name. Equivalent to inserting
     * all fields into a {@link java.util.TreeMap} keyed by name, but cheaper since R.txt files are
     * typically already sorted.
     */
    private static ImmutableList<FieldInitializer> sortAndDedupeByName(
        List<FieldInitializer> fields) {
      // List.sort is stable, so duplicates stay in encounter order.
      fields.sort(Comparator.comparing(FieldInitializer::getFieldName));
      ImmutableList.Builder<FieldInitializer> result =
          ImmutableList.builderWithExpectedSize(fields.size());
      for (int i = 0; i < fields.size(); i++) {
        if (i + 1 == fields.size()
            || !fields.get(i).getFieldName().equals(fields.get(i + 1).getFieldName())) {
          result.add(fields.get(i));
        }
      }
      return result.build();
    }
  }

  private static final class PackageParsingTask implements Callable<String> {

    private static final SAXParserFactory PARSER_FACTORY =
        XmlUtils.configureSaxFactory(
            SAXParserFactory.newInstance(), /* namespaceAware= */ true, /* checkDtd= */ false);

    /** SAX parsers are not thread-safe, but can be reused for sequential parses. */
    private static final ThreadLocal<SAXParser> PARSER =
        ThreadLocal.withInitial(
            () -> {
              try {
                synchronized (PARSER_FACTORY) {
                  return XmlUtils.createSaxParser(PARSER_FACTORY);
                }
              } catch (ParserConfigurationException | SAXException e) {
                throw new IllegalStateException(e);
              }
            });

    private final File manifest;

    PackageParsingTask(File manifest) {
      this.manifest = manifest;
    }

    /**
     * Equivalent to {@code DefaultManifestParser.getPackage()}, which serializes all parsing
     * behind a global lock and creates a new parser for each file.
     */
    @Override
    public String call() throws IOException, SAXException {
      if (!manifest.isFile()) {
        throw new FileNotFoundException(
            "Manifest file does not exist: " + manifest.getAbsolutePath());
      }
      String[] packageName = new String[1];
      DefaultHandler handler =
          new DefaultHandler() {
            @Override
            public void startElement(
                String uri, String localName, String qName, Attributes attributes) {
              if (Strings.isNullOrEmpty(uri) && localName.equals(SdkConstants.TAG_MANIFEST)) {
                String value = attributes.getValue("", SdkConstants.ATTR_PACKAGE);
                if (value != null && !PlaceholderHandler.isPlaceHolder(value)) {
                  packageName[0] = value;
                }
              }
            }
          };
      SAXParser parser = PARSER.get();
      try {
        parser.parse(manifest, handler);
      } catch (IOException | SAXException | RuntimeException e) {
        PARSER.remove();
        throw e;
      }
      return packageName[0];
    }
  }

  /**
   * An interface to make the {@link loadFrom} function below able to receive {@link
   * DependencyAndroidData} and ${@link DependencySymbolProvider}
   */
  public interface SymbolFileProvider extends ManifestProvider {
    File getSymbolFile();
  }

  /**
   * Loads the SymbolTables from a list of DependencyAndroidData objects.
   *
   * @param dependencies The full set of library symbols to load.
   * @param executor The executor use during loading.
   * @param packageToExclude A string package to elide if it exists in the providers.
   * @return A list of loading {@link ResourceSymbols} instances.
   * @throws ExecutionException
   * @throws InterruptedException when there is an error loading the symbols.
   */
  public static Multimap<String, ListenableFuture<ResourceSymbols>> loadFrom(
      Iterable<? extends SymbolFileProvider> dependencies,
      ListeningExecutorService executor,
      @Nullable String packageToExclude)
      throws InterruptedException, ExecutionException {
    Map<SymbolFileProvider, ListenableFuture<String>> providerToPackage = new LinkedHashMap<>();
    for (SymbolFileProvider dependency : dependencies) {
      providerToPackage.put(
          dependency, executor.submit(new PackageParsingTask(dependency.getManifest())));
    }
    Multimap<String, ListenableFuture<ResourceSymbols>> packageToTable =
        LinkedHashMultimap.create();
    for (Map.Entry<SymbolFileProvider, ListenableFuture<String>> entry :
        providerToPackage.entrySet()) {
      File symbolFile = entry.getKey().getSymbolFile();
      if (!Objects.equals(entry.getValue().get(), packageToExclude)) {
        packageToTable.put(entry.getValue().get(), load(symbolFile.toPath(), executor));
      }
    }
    return packageToTable;
  }

  public static ResourceSymbols from(FieldInitializers fieldInitializers) {
    return new ResourceSymbols(fieldInitializers);
  }

  public static ResourceSymbols merge(Collection<ResourceSymbols> symbolTables) {
    List<FieldInitializers> fieldInitializers = new ArrayList<>(symbolTables.size());
    for (ResourceSymbols symbolTableProvider : symbolTables) {
      fieldInitializers.add(symbolTableProvider.asInitializers());
    }
    return from(FieldInitializers.mergedFrom(fieldInitializers));
  }

  /** Read the symbols from the provided symbol file. */
  public static ListenableFuture<ResourceSymbols> load(
      Path primaryRTxt, ListeningExecutorService executorService) {
    return executorService.submit(new SymbolLoadingTask(primaryRTxt));
  }

  private final FieldInitializers values;

  private ResourceSymbols(FieldInitializers fieldInitializers) {
    this.values = fieldInitializers;
  }

  /**
   * Writes the java sources for a given package.
   *
   * @param sourceOut The directory to write the java package structures and sources to.
   * @param packageName The name of the package to write.
   * @param packageSymbols The symbols defined in the given package.
   * @param finalFields
   * @throws IOException when encountering an error during writing.
   */
  public void writeSourcesTo(
      Path sourceOut,
      String packageName,
      Collection<ResourceSymbols> packageSymbols,
      boolean finalFields)
      throws IOException {
    RSourceGenerator.with(sourceOut, asInitializers(), finalFields)
        .write(packageName, merge(packageSymbols).asInitializers());
  }

  public FieldInitializers asInitializers() {
    return values;
  }

  /**
   * Generates the R classes for the given packages, storing them in {@code classFiles} keyed by
   * their path under {@code classesOut}.
   */
  public void writeClassesTo(
      Multimap<String, ResourceSymbols> libMap,
      String appPackageName,
      Path classesOut,
      ConcurrentMap<Path, byte[]> classFiles,
      boolean finalFields,
      RPackageId rPackageId)
      throws IOException {
    RClassGenerator classWriter =
        RClassGenerator.inMemory(
            /* label= */ null,
            classesOut,
            classFiles,
            values,
            finalFields,
            /* annotateTransitiveFields= */ false,
            rPackageId);
    // Packages are independent, so they can be written in parallel.
    ExecutorService executor =
        Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors());
    try {
      List<Future<?>> futures = new ArrayList<>();
      for (Map.Entry<String, Collection<ResourceSymbols>> entry : libMap.asMap().entrySet()) {
        String packageName = entry.getKey();
        ImmutableList<FieldInitializers> packageInitializers =
            entry.getValue().stream()
                .map(ResourceSymbols::asInitializers)
                .collect(toImmutableList());
        futures.add(
            executor.submit(
                () -> {
                  classWriter.write(packageName, packageInitializers);
                  return null;
                }));
      }
      if (appPackageName != null) {
        // Unlike the R.java generation, we also write the app's R.class file so that the class
        // jar file can be complete (aapt doesn't generate it for us).
        futures.add(
            executor.submit(
                () -> {
                  classWriter.write(appPackageName);
                  return null;
                }));
      }
      for (Future<?> future : futures) {
        Uninterruptibles.getUninterruptibly(future);
      }
    } catch (ExecutionException e) {
      Throwables.throwIfInstanceOf(e.getCause(), IOException.class);
      Throwables.throwIfUnchecked(e.getCause());
      throw new IllegalStateException(e.getCause());
    } finally {
      executor.shutdownNow();
    }
  }
}
