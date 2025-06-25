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

import static java.nio.charset.StandardCharsets.UTF_8;

import com.beust.jcommander.IStringConverter;
import com.beust.jcommander.IValueValidator;
import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;
import com.beust.jcommander.ParameterException;
import com.beust.jcommander.Parameters;
import com.google.common.annotations.VisibleForTesting;
import com.google.common.base.Joiner;
import com.google.common.base.Stopwatch;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableSetMultimap;
import com.google.common.collect.Multimap;
import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Enumeration;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.TimeUnit;
import java.util.logging.Logger;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;

/**
 * Action to filter entries out of a Zip file.
 *
 * <p>The entries to remove are determined from the filterZips and filterTypes. All entries from the
 * filter Zip files that have an extension listed in filterTypes will be removed. If no filterZips
 * are specified, no entries will be removed. Specifying no filterTypes is treated as if an
 * extension of '.*' was specified.
 *
 * <p>Assuming each Zip as a set of entries, the result is:
 *
 * <pre> outputZip = inputZip - union[x intersect filterTypes for x in filterZips]</pre>
 *
 * <p>
 *
 * <pre>
 * Example Usage:
 *   java/com/google/build/android/ZipFilterAction\
 *      --inputZip path/to/inputZip
 *      --outputZip path/to/outputZip
 *      --filterZips [path/to/filterZip[,path/to/filterZip]...]
 *      --filterTypes [fileExtension[,fileExtension]...]
 *      --explicitFilters [fileRegex[,fileRegex]...]
 *      --outputMode [DONT_CARE|FORCE_DEFLATE|FORCE_STORED]
 *      --checkHashMismatch [IGNORE|WARN|ERROR]
 * </pre>
 */
public class ZipFilterAction {
  /** A copy of Bazel's singlejar.ZipCombiner#OutputMode enum. */
  enum OutputMode {

    /** Output entries using any method. */
    DONT_CARE,

    /**
     * Output all entries using DEFLATE method, except directory entries. It is always more
     * efficient to store directory entries uncompressed.
     */
    FORCE_DEFLATE,

    /** Output all entries using STORED method. */
    FORCE_STORED,
  }

  record GenerateExcludeListResult(int sawErrors, ArrayList<String> excludeList) {}

  private static final Logger logger = Logger.getLogger(ZipFilterAction.class.getName());

  /** Modes of performing content hash checking during zip filtering. */
  public enum HashMismatchCheckMode {
    /** Filter file from input zip iff a file is found with the same filename in filter zips. */
    IGNORE,

    /**
     * Filter file from input zip iff a file is found with the same filename and content hash in
     * filter zips. Print warning if the filename is identical but content hash is not.
     */
    WARN,

    /**
     * Same behavior as WARN, but throw an error if a file is found with the same filename with
     * different content hash.
     */
    ERROR
  }

  @Parameters()
  static class Options {
    @Parameter(
      names = "--inputZip",
      description = "Path of input zip.",
      converter = PathFlagConverter.class,
      validateValueWith = PathExistsValidator.class
    )
    Path inputZip;

    @Parameter(
      names = "--outputZip",
      description = "Path to write output zip.",
      converter = PathFlagConverter.class
    )
    Path outputZip;

    @Parameter(
      names = "--filterZips",
      description = "Filter zips.",
      converter = PathFlagConverter.class,
      validateValueWith = AllPathsExistValidator.class
    )
    List<Path> filterZips = ImmutableList.of();

    @Parameter(names = "--filterTypes", description = "Filter file types.")
    List<String> filterTypes = ImmutableList.of();

    @Parameter(names = "--explicitFilters", description = "Explicitly specified filters.")
    List<String> explicitFilters = ImmutableList.of();

    @Parameter(names = "--outputMode", description = "Output zip compression mode.")
    OutputMode outputMode = OutputMode.DONT_CARE;

    @Parameter(
      names = "--checkHashMismatch",
      description =
          "Ignore, warn or throw an error if the content hashes of two files with the "
              + "same name are different."
    )
    HashMismatchCheckMode hashMismatchCheckMode = HashMismatchCheckMode.WARN;
  }

  /** Converts string flags to paths. Public because JCommander invokes this by reflection. */
  public static class PathFlagConverter implements IStringConverter<Path> {

    @Override
    public Path convert(String text) {
      return FileSystems.getDefault().getPath(text);
    }
  }

  /** Validates that a path exists. Public because JCommander invokes this by reflection. */
  public static class PathExistsValidator implements IValueValidator<Path> {

    @Override
    public void validate(String s, Path path) {
      if (!Files.exists(path)) {
        throw new ParameterException(String.format("%s is not a valid path.", path.toString()));
      }
    }
  }

  /** Validates that a set of paths exist. Public because JCommander invokes this by reflection. */
  public static class AllPathsExistValidator implements IValueValidator<List<Path>> {

    @Override
    public void validate(String s, List<Path> paths) {
      for (Path path : paths) {
        if (!Files.exists(path)) {
          throw new ParameterException(String.format("%s is not a valid path.", path.toString()));
        }
      }
    }
  }

  @VisibleForTesting
  static Multimap<String, Long> getEntriesToOmit(
      Collection<Path> filterZips, Collection<String> filterTypes) throws IOException {
    // Escape filter types to prevent regex abuse
    Set<String> escapedFilterTypes = new LinkedHashSet<>();
    for (String filterType : filterTypes) {
      escapedFilterTypes.add(Pattern.quote(filterType));
    }
    // Match any string that ends with any of the filter file types
    String filterRegex = String.format(".*(%s)$", Joiner.on("|").join(escapedFilterTypes));
    Pattern filterPattern = Pattern.compile(filterRegex);

    ImmutableSetMultimap.Builder<String, Long> entriesToOmit = ImmutableSetMultimap.builder();
    for (Path filterZip : filterZips) {
      try (ZipFile zf = new ZipFile(filterZip.toFile())) {
        Enumeration<? extends ZipEntry> entries = zf.entries();

        while (entries.hasMoreElements()) {
          ZipEntry entry = entries.nextElement();
          if (filterTypes.isEmpty() || filterPattern.matcher(entry.getName()).matches()) {
            entriesToOmit.put(entry.getName(), entry.getCrc());
          }
        }
      }
    }
    return entriesToOmit.build();
  }

  public static void main(String[] args) throws IOException {
    System.exit(run(args));
  }

  static GenerateExcludeListResult generateExcludeList(Options options, Stopwatch timer)
      throws IOException {
    Multimap<String, Long> entriesToOmit =
        getEntriesToOmit(options.filterZips, options.filterTypes);
    final String explicitFilter =
        options.explicitFilters.isEmpty()
            ? ""
            : String.format(".*(%s).*", Joiner.on("|").join(options.explicitFilters));
    logger.fine(String.format("Filter created in %dms", timer.elapsed(TimeUnit.MILLISECONDS)));
    ArrayList<String> excludeList = new ArrayList<>();

    int sawErrors = 0;
    try (ZipFile zf = new ZipFile(options.inputZip.toFile());
        ZipOutputStream zos =
            new ZipOutputStream(new FileOutputStream(options.outputZip.toString()))) {
      Enumeration<? extends ZipEntry> entries = zf.entries();

      while (entries.hasMoreElements()) {
        ZipEntry entry = entries.nextElement();
        if (entry.getName().matches(explicitFilter)) {
          excludeList.add(entry.getName());
        } else if (entriesToOmit.containsEntry(entry.getName(), entry.getCrc())) {
          excludeList.add(entry.getName());
        } else if (entriesToOmit.containsKey(entry.getName())) {
          // entriesToOmit contains the filename, but a different CRC was observed.
          if (options.hashMismatchCheckMode == HashMismatchCheckMode.IGNORE) {
            // Just add it to the excluded entry list.
            excludeList.add(entry.getName());
          } else {
            if (options.hashMismatchCheckMode == HashMismatchCheckMode.ERROR) {
              logger.severe(
                  String.format(
                      "ERROR: Requested to filter entries of name "
                          + "'%s'; name matches but the hash does not.\n",
                      entry.getName()));
              sawErrors = 1;
              excludeList.add(entry.getName());
            } else {
              logger.severe(
                  String.format(
                      "WARNING: Requested to filter entries of name "
                          + "'%s'; name matches but the hash does not. Copying anyway.\n",
                      entry.getName()));
            }
          }
        }
      }
    }
    return new GenerateExcludeListResult(sawErrors, excludeList);
  }

  @SuppressWarnings("RuntimeExec")
  static int run(String[] args) throws IOException {
    Options options = new Options();
    new JCommander(options).parse(args);
    logger.fine(
        String.format(
            "Creating filter from entries of type %s, in zip files %s.",
            options.filterTypes, options.filterZips));

    String compressionStrategy = "--dont_change_compression";
    if (options.outputMode == OutputMode.FORCE_STORED) {
      compressionStrategy = "--compression";
    } else if (options.outputMode == OutputMode.FORCE_DEFLATE) {
      throw new IllegalArgumentException("FORCE_DEFLATE is not supported.");
    }

    String singleJarPath =
        Path.of(System.getProperty("runfiles.path"), System.getProperty("singlejar.path"))
            .toString();
    ImmutableList.Builder<String> singleJarArgsBuilder = ImmutableList.builder();
    singleJarArgsBuilder
        .add("--sources")
        .add(options.inputZip.toString())
        .add("--output")
        .add(options.outputZip.toString())
        .add(compressionStrategy)
        .add("--exclude_build_data")
        .add("--normalize");

    final Stopwatch timer = Stopwatch.createStarted();
    GenerateExcludeListResult excludeListResult = generateExcludeList(options, timer);
    int sawErrors = excludeListResult.sawErrors();
    ArrayList<String> excludeList = excludeListResult.excludeList();

    if (!excludeList.isEmpty()) {
      singleJarArgsBuilder.add("--exclude_zip_entries").addAll(excludeList);
    }

    ImmutableList<String> singleJarArgs = singleJarArgsBuilder.build();
    // Dump the singlejar args into a params file
    File paramsFile = File.createTempFile("singlejar_params", ".txt");
    try (BufferedWriter writer = Files.newBufferedWriter(paramsFile.toPath(), UTF_8)) {
      for (String arg : singleJarArgs) {
        writer.write(arg + "\n");
      }
    }

    boolean singleJarError = false;
    Process singleJarProcess =
        Runtime.getRuntime().exec(new String[] {singleJarPath, "@" + paramsFile.getAbsolutePath()});
    try {
      int singlejarExitCode = singleJarProcess.waitFor();
      if (singlejarExitCode != 0) {
        sawErrors = 1;
        singleJarError = true;
        logger.severe(
            String.format(
                "ERROR: singlejar failed with exit code %d. See logs for details.",
                singlejarExitCode));
      }
    } catch (InterruptedException e) {
      singleJarError = true;
      logger.severe(String.format("ERROR: singlejar was interrupted: %s", e.getMessage()));
      sawErrors = 1;
    }
    // Dump out the singlejar stderr if there was an issue.
    if (singleJarError) {
      InputStreamReader isr = new InputStreamReader(singleJarProcess.getErrorStream(), UTF_8);
      BufferedReader br = new BufferedReader(isr);
      String line;
      while ((line = br.readLine()) != null) {
        System.out.println("  [singlejar stderr] " + line);
      }
    }
    logger.fine(String.format("Filtering completed in %dms", timer.elapsed(TimeUnit.MILLISECONDS)));

    return sawErrors;
  }
}
