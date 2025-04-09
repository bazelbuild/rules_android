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

import static java.nio.charset.StandardCharsets.UTF_8;
import static java.util.concurrent.TimeUnit.MILLISECONDS;

import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;
import com.beust.jcommander.ParameterException;
import com.beust.jcommander.Parameters;
import com.google.common.collect.Sets;
import com.google.common.io.ByteStreams;
import com.google.devtools.build.android.Converters.CompatExistingPathConverter;
import com.google.devtools.build.android.Converters.CompatPathConverter;
import com.google.devtools.build.android.r8.CompatDexBuilder;
import com.google.devtools.build.android.r8.Constants;
import com.google.devtools.build.android.r8.Desugar;
import com.google.devtools.build.zip.ZipFileEntry;
import com.google.devtools.build.zip.ZipReader;
import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutionException;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

/** The entrypoint binary for the mobile-install DesugarDexSharding action. */
final class DesugarDexShardingAction {
  // January 1, 2010 UTC
  private static final FileTime DEFAULT_TIMESTAMP = FileTime.from(1262304000000L, MILLISECONDS);
  private static final long DEFAULT_TIMESTAMP_MILLIS = DEFAULT_TIMESTAMP.toMillis();

  /** Commandline options for {@link DesugarDexShardingAction}. */
  @Parameters(separators = "= ")
  public static class Options {
    @Parameter(
        names = "-android_jar",
        converter = CompatExistingPathConverter.class,
        description = "Path to the android.jar")
    public Path androidJar;

    @Parameter(
        names = "-classpath",
        converter = CompatExistingPathConverter.class,
        description = "Path(s) to the classpaths")
    public List<Path> classpaths;

    @Parameter(
        names = "-desugar_core_libs",
        description = "Enable core library desugaring",
        arity = 1)
    public boolean desugarCoreLibs;

    @Parameter(
        names = "-desugared_lib_config",
        converter = CompatExistingPathConverter.class,
        description = "The JSON config for library desugaring")
    public Path desugaredLibConfig;

    @Parameter(
        names = "-in",
        converter = CompatExistingPathConverter.class,
        description = "Path to the input jar")
    public Path inputJar;

    @Parameter(
        names = "-out",
        converter = CompatPathConverter.class,
        description = "Path to output, if more than one specified, output is sharded across files.")
    public List<Path> outs;

    @Parameter(
        names = "-min_sdk_version",
        description =
            "Minimum targeted sdk version.  If >= 24, enables default methods in interfaces.")
    public int minSdkVersion = Integer.parseInt(Constants.MIN_API_LEVEL);

    @Parameter(
        names = "--persistent_worker",
        arity = 1,
        description = "Whether the action is running as a persistent worker. Does not work yet.")
    public boolean persistentWorker;
  }

  private DesugarDexShardingAction() {}

  private static boolean hasCode(Path in) throws IOException {
    try (ZipReader zip = new ZipReader(in.toFile())) {
      for (ZipFileEntry entry : zip.entries()) {
        if (entry.getName().endsWith(".class") || entry.getName().endsWith(".dex")) {
          return true;
        }
      }
    } catch (IOException e) {
      throw new IOException("Failed to open zip file: " + in, e);
    }
    return false;
  }

  private static void desugar(Options options, Path jar) throws Exception {
    // Wrapper for the desugar tool.
    List<String> args =
        new ArrayList<>(
            Arrays.asList(
                "--input",
                options.inputJar.toString(),
                "--bootclasspath_entry",
                options.androidJar.toString(),
                "--output",
                jar.toString()));

    if (options.minSdkVersion > 0) {
      args.add("--min_sdk_version");
      args.add(Integer.toString(options.minSdkVersion));
    }

    if (options.desugarCoreLibs) {
      args.add("--desugar_supported_core_libs");
    }
    if (options.desugaredLibConfig != null) {
      args.add("--desugared_lib_config");
      args.add(options.desugaredLibConfig.toString());
    }

    for (Path classpath : options.classpaths) {
      args.add("--classpath_entry");
      args.add(classpath.toString());
    }

    int exitCode = Desugar.processRequest(args, System.err);
    if (exitCode != 0) {
      throw new IllegalStateException("Desugar failed with exit code: " + exitCode);
    }
  }

  private static void dexbuilder(Options options, Path jar, Path outputZip)
      throws ExecutionException {
    // Wrapper for the dexbuilder tool.
    List<String> args =
        new ArrayList<>(
            Arrays.asList("--input_jar", jar.toString(), "--output_zip", outputZip.toString()));

    if (options.minSdkVersion > 0) {
      args.add("--min_sdk_version");
      args.add(Integer.toString(options.minSdkVersion));
    }

    CompatDexBuilder compatDexBuilder = new CompatDexBuilder();
    compatDexBuilder.dexEntries(args);
  }

  private static int indexAny(String s, char[] chars) {
    // Java implementation of go's strings.IndexAny method
    // See https://pkg.go.dev/strings#IndexAny
    // For a given string `s`, returns the first index of any character in `s` that is in `chars`.

    Set<Character> charSet = Sets.newHashSetWithExpectedSize(chars.length);
    for (char c : chars) {
      charSet.add(c);
    }

    for (int i = 0; i < s.length(); i++) {
      if (charSet.contains(s.charAt(i))) {
        return i;
      }
    }
    return -1;
  }

  private static int shardFn(String name, int shardCount) {
    // Sharding function which ensures that a class and all its inner classes are
    // placed in the same shard. An important side effect of this is that all D8
    // synthetics are in the same shard as their context, as a synthetic is named
    // <context>$$ExternalSyntheticXXXN.
    int index = name.length();

    if (name.endsWith(".class.dex")) {
      // DexBuilder creates archives with .class.dex files
      index -= 10;
    } else if (name.endsWith(".dex")) {
      // D8 creates archives with .dex files
      index -= 4;
    } else {
      throw new IllegalArgumentException(
          "Name expected to end with '.dex' or '.class.dex', was: " + name);
    }

    final char[] specialChars = {'$', '-'};
    int trimIndex = indexAny(name, specialChars);
    if (trimIndex > -1) {
      index = trimIndex;
    }

    // Return the hash of the substring starting from index.
    String nameToHash = name.substring(0, index);
    long hash = Fnv1a32bHash.hash(nameToHash.getBytes(UTF_8));
    return Math.floorMod(hash, shardCount);
  }

  private static void zipShard(Path zip, List<Path> outs) throws IOException {
    if (outs.size() < 2) {
      throw new IllegalArgumentException("Need at least two output shards!");
    }

    List<ZipOutputStream> zipOuts = new ArrayList<>(outs.size());
    for (Path out : outs) {
      zipOuts.add(new ZipOutputStream(new FileOutputStream(out.toFile())));
    }

    // Open the input zip file of dexes
    try (ZipFile zipFile = new ZipFile(zip.toFile());
        ZipInputStream zis = new ZipInputStream(new FileInputStream(zip.toFile()))) {
      // For each entry in the zip file, compute its hash.
      ZipEntry entry;
      while ((entry = zis.getNextEntry()) != null) {
        InputStream currFileStream = zipFile.getInputStream(entry);
        String fileName = entry.getName();
        // Skip if not a dex file or is a directory.
        if (entry.isDirectory() || !fileName.endsWith(".dex")) {
          currFileStream.close();
          continue;
        }
        int shardIdx = shardFn(fileName, outs.size());

        ZipEntry newEntry = new ZipEntry(fileName);
        newEntry.setMethod(ZipEntry.STORED);
        newEntry.setSize(entry.getSize());
        newEntry.setCompressedSize(entry.getSize());
        newEntry.setCrc(entry.getCrc());
        newEntry.setTime(DEFAULT_TIMESTAMP_MILLIS);

        ZipOutputStream zipOut = zipOuts.get(shardIdx);
        zipOut.putNextEntry(newEntry);
        ByteStreams.copy(currFileStream, zipOut);
        zipOut.closeEntry();

        currFileStream.close();
      }

    } catch (IOException e) {
      throw new IOException("Failed to open zip file: " + zip, e);
    }

    for (ZipOutputStream zipOut : zipOuts) {
      zipOut.close();
    }
  }

  public static void main(String[] args) throws Exception {
    List<String> argsList = new ArrayList<>(Arrays.asList(args));
    Options options = new Options();

    final String flagfilePrefix = "-flagfile=";

    // Deal with param files.
    if (args.length >= 1 && args[0].startsWith(flagfilePrefix)) {
      argsList.clear();
      // Check if the first argument is a flagfile
      String flagfile = args[0].substring(flagfilePrefix.length());

      // Read the flagfile
      try (BufferedReader reader = Files.newBufferedReader(Path.of(flagfile))) {
        String line;
        while ((line = reader.readLine()) != null) {
          argsList.add(line);
        }
      }
    }

    JCommander.newBuilder().addObject(options).build().parse(argsList.toArray(new String[0]));

    if (options.androidJar == null) {
      throw new ParameterException("--android_jar is required for desugaring.");
    }

    if (options.inputJar == null || options.outs.toString().isEmpty()) {
      throw new ParameterException("--in and --out are required for desugaring.");
    }

    int shardCount = options.outs.size();
    if (shardCount > 256) {
      throw new ParameterException(
          shardCount + " is an unreasonable shard count (want [1 to 256])");
    }

    // Create a dex tempdir for each shard.
    Path dexDir = Files.createTempDirectory("dex");

    // Check if the input jar has any code
    boolean jarHasCode = hasCode(options.inputJar);

    if (jarHasCode) {
      Path jar = Path.of(dexDir.toString(), "desugared.jar");

      desugar(options, jar);

      if (shardCount == 1) {
        // If the shardCount is 1, write the output dexes to outs[0]
        dexbuilder(options, jar, options.outs.get(0));
      } else {
        // Otherwise, write the output dexes to a single zip file, then shard the zip.
        Path zip = Path.of(dexDir.toString(), "dexed.zip");
        dexbuilder(options, jar, zip);
        // Shard the zip file.
        zipShard(zip, options.outs);
      }
    } else {
      // Write empty zip files for each output shard.
      // Relevant in the case of no class/dex files in the input jar.
      for (Path out : options.outs) {
        try (FileOutputStream fos = new FileOutputStream(out.toFile());
            ZipOutputStream zip = new ZipOutputStream(fos)) {}
      }
    }
  }
}
