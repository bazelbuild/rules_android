/*
 * Copyright 2023 The Bazel Authors. All rights reserved.

 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 *   http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

package com.google.devtools.build.android.shrinker;

import com.android.build.shrinker.ResourceShrinkerImpl;
import com.android.build.shrinker.FileReporter;
import com.android.build.shrinker.NoDebugReporter;
import com.android.build.shrinker.LinkedResourcesFormat;
import com.android.build.shrinker.gatherer.ProtoResourceTableGatherer;
import com.android.build.shrinker.gatherer.ResourcesGatherer;
import com.android.build.shrinker.graph.ProtoResourcesGraphBuilder;
import com.android.build.shrinker.obfuscation.ProguardMappingsRecorder;
import com.android.build.shrinker.usages.DexUsageRecorder;
import com.android.build.shrinker.usages.ProtoAndroidManifestUsageRecorder;
import com.android.build.shrinker.usages.ResourceUsageRecorder;
import com.android.build.shrinker.usages.ToolsAttributeUsageRecorder;
import com.android.utils.FileUtils;
import java.io.IOException;
import java.io.PrintStream;
import java.nio.file.FileSystem;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.zip.ZipFile;
import javax.xml.parsers.ParserConfigurationException;
import org.xml.sax.SAXException;

public class BazelResourceShrinkerCli {

    private static final String INPUT_ARG = "--input";
    private static final String DEX_INPUT_ARG = "--dex_input";
    private static final String OUTPUT_ARG = "--output";
    private static final String RES_ARG = "--raw_resources";
    private static final String PRECISE_SHRINKING_ARG = "--precise_shrinking";
    private static final String PROGUARD_MAPPING_ARG = "--proguard_mapping";
    private static final String HELP_ARG = "--help";
    private static final String PRINT_USAGE_LOG = "--print_usage_log";

    private static final String ANDROID_MANIFEST_XML = "AndroidManifest.xml";
    private static final String RESOURCES_PB = "resources.pb";
    private static final String RES_FOLDER = "res";

    private static class Options {
        private String input;
        private final List<String> dex_inputs = new ArrayList<>();
        private String output;
        private String usageLog;
        private Boolean preciseShrinking = Boolean.FALSE;
        private final List<String> rawResources = new ArrayList<>();
        private String proguardMapping;
        private boolean help;

        private Options() {}

        public static Options parseOptions(String[] args) {
            Options options = new Options();
            for (int i = 0; i < args.length; i++) {
                String arg = args[i];
                if (arg.startsWith(INPUT_ARG)) {
                    i++;
                    if (i == args.length) {
                        throw new ResourceShrinkingFailedException("No argument given for input");
                    }
                    if (options.input != null) {
                        throw new ResourceShrinkingFailedException(
                                "More than one input not supported");
                    }
                    options.input = args[i];
                } else if (arg.startsWith(OUTPUT_ARG)) {
                    i++;
                    if (i == args.length) {
                        throw new ResourceShrinkingFailedException("No argument given for output");
                    }
                    if (options.output != null) {
                        throw new ResourceShrinkingFailedException(
                                "More than one output not supported");
                    }
                    options.output = args[i];
                } else if (arg.startsWith(DEX_INPUT_ARG)) {
                    i++;
                    if (i == args.length) {
                        throw new ResourceShrinkingFailedException(
                                "No argument given for dex_input");
                    }
                    options.dex_inputs.add(args[i]);
                } else if (arg.startsWith(PROGUARD_MAPPING_ARG)) {
                    i++;
                    if (i == args.length) {
                        throw new ResourceShrinkingFailedException("No argument given for proguard_mapping");
                    }
                    if (options.proguardMapping != null) {
                        throw new ResourceShrinkingFailedException(
                                "More than one proguard mapping file is not supported");
                    }
                    options.proguardMapping = args[i];
                } else if (arg.startsWith(PRECISE_SHRINKING_ARG)) {
                    i++;
                    if (i == args.length) {
                        throw new ResourceShrinkingFailedException(
                                "No argument given for --precise_shrinking");
                    }
                    options.preciseShrinking = Boolean.parseBoolean(args[i]);

                } else if (arg.startsWith(PRINT_USAGE_LOG)) {
                    i++;
                    if (i == args.length) {
                        throw new ResourceShrinkingFailedException(
                                "No argument given for usage log");
                    }
                    if (options.usageLog != null) {
                        throw new ResourceShrinkingFailedException(
                                "More than usage log not supported");
                    }
                    options.usageLog = args[i];
                } else if (arg.startsWith(RES_ARG)) {
                    i++;
                    if (i == args.length) {
                        throw new ResourceShrinkingFailedException(
                                "No argument given for raw_resources");
                    }
                    options.rawResources.add(args[i]);
                } else if (arg.equals(HELP_ARG)) {
                    options.help = true;
                } else {
                    throw new ResourceShrinkingFailedException("Unknown argument " + arg);
                }
            }
            return options;
        }

        public String getInput() {
            return input;
        }

        public String getOutput() {
            return output;
        }

        public String getUsageLog() {
            return usageLog;
        }

        public String getProguardMapping() {
            return proguardMapping;
        }

        public Boolean getPreciseShrinking() {
            return preciseShrinking;
        }

        public List<String> getRawResources() {
            return rawResources;
        }

        public boolean isHelp() {
            return help;
        }
    }

    public static void main(String[] args) {
        run(args);
    }

    protected static ResourceShrinkerImpl run(String[] args) {
        try {
            Options options = Options.parseOptions(args);
            if (options.isHelp()) {
                printUsage();
                return null;
            }
            validateOptions(options);
            ResourceShrinkerImpl resourceShrinker = runResourceShrinking(options);
            return resourceShrinker;
        } catch (IOException | ParserConfigurationException | SAXException e) {
            throw new ResourceShrinkingFailedException(
                    "Failed running resource shrinking: " + e.getMessage(), e);
        }
    }

    private static ResourceShrinkerImpl runResourceShrinking(Options options)
            throws IOException, ParserConfigurationException, SAXException {
        validateInput(options.getInput());
        List<ResourceUsageRecorder> resourceUsageRecorders = new ArrayList<>();
        for (String dexInput : options.dex_inputs) {
            validateFileExists(dexInput);
            // SNAP: Support passing in feature DEXs directly
            if (dexInput.endsWith(".zip")) {
                resourceUsageRecorders.add(
                        new DexUsageRecorder(
                                FileUtils.createZipFilesystem(Paths.get(dexInput)).getPath("")));
            } else {
                resourceUsageRecorders.add(new DexUsageRecorder(Paths.get(dexInput)));
            }
        }
        Path protoApk = Paths.get(options.getInput());
        Path protoApkOut = Paths.get(options.getOutput());
        FileSystem fileSystemProto = FileUtils.createZipFilesystem(protoApk);
        resourceUsageRecorders.add(new DexUsageRecorder(fileSystemProto.getPath("")));
        resourceUsageRecorders.add(
                new ProtoAndroidManifestUsageRecorder(
                        fileSystemProto.getPath(ANDROID_MANIFEST_XML)));
        for (String rawResource : options.getRawResources()) {
            resourceUsageRecorders.add(new ToolsAttributeUsageRecorder(Paths.get(rawResource)));
        }
        // If the apk contains a raw folder, find keep rules in there
        if (new ZipFile(options.getInput())
                .stream().anyMatch(zipEntry -> zipEntry.getName().startsWith("res/raw"))) {
            Path rawPath = fileSystemProto.getPath("res", "raw");
            resourceUsageRecorders.add(new ToolsAttributeUsageRecorder(rawPath));
        }
        ResourcesGatherer gatherer =
                new ProtoResourceTableGatherer(fileSystemProto.getPath(RESOURCES_PB));
        ProtoResourcesGraphBuilder res =
                new ProtoResourcesGraphBuilder(
                        fileSystemProto.getPath(RES_FOLDER), fileSystemProto.getPath(RESOURCES_PB));
        ProguardMappingsRecorder proguardMappingsRecorder = null; 
        if (options.getProguardMapping() != null ) {
            new ProguardMappingsRecorder(Paths.get(options.getProguardMapping()));
        }
        ResourceShrinkerImpl resourceShrinker =
                new ResourceShrinkerImpl(
                        List.of(gatherer),
                        proguardMappingsRecorder,
                        resourceUsageRecorders,
                        List.of(res),
                        options.usageLog != null
                                ? new FileReporter(Paths.get(options.usageLog).toFile())
                                : NoDebugReporter.INSTANCE,
                        false, // TODO(b/245721267): Add support for bundles
                        options.getPreciseShrinking());
        resourceShrinker.analyze();

        resourceShrinker.rewriteResourcesInApkFormat(
                protoApk.toFile(), protoApkOut.toFile(), LinkedResourcesFormat.PROTO);
        return resourceShrinker;
    }

    private static void validateInput(String input) throws IOException {
        ZipFile zipfile = new ZipFile(input);
        if (zipfile.getEntry(ANDROID_MANIFEST_XML) == null) {
            throw new ResourceShrinkingFailedException(
                    "Input must include " + ANDROID_MANIFEST_XML);
        }
        if (zipfile.getEntry(RESOURCES_PB) == null) {
            throw new ResourceShrinkingFailedException(
                    "Input must include "
                            + RESOURCES_PB
                            + ". Did you not convert the input apk"
                            + " to proto?");
        }
        if (zipfile.stream().noneMatch(zipEntry -> zipEntry.getName().startsWith(RES_FOLDER))) {
            throw new ResourceShrinkingFailedException(
                    "Input must include a " + RES_FOLDER + " folder");
        }
    }

    private static void validateFileExists(String file) {
        if (!Paths.get(file).toFile().exists()) {
            throw new RuntimeException("Can't find file: " + file);
        }
    }

    private static void validateOptions(Options options) {
        if (options.getInput() == null) {
            throw new ResourceShrinkingFailedException("No input given.");
        }
        if (options.getOutput() == null) {
            throw new ResourceShrinkingFailedException("No output destination given.");
        }
        validateFileExists(options.getInput());
        for (String rawResource : options.getRawResources()) {
            validateFileExists(rawResource);
        }
    }

    private static void printUsage() {
        PrintStream out = System.err;
        out.println("Usage:");
        out.println("  resourceshrinker ");
        out.println("    --input <input-file>, container with manifest, resources table and res");
        out.println("      folder. May contain dex.");
        out.println("    --dex_input <input-file> Container with dex files (only dex will be ");
        out.println("       handled if this contains other files. Several --dex_input arguments");
        out.println("       are supported");
        out.println("    --output <output-file>");
        out.println("    --raw_resource <xml-file or res directory>");
        out.println("      optional, more than one raw_resoures argument might be given");
        out.println("    --help prints this help message");
    }

    private static class ResourceShrinkingFailedException extends RuntimeException {
        public ResourceShrinkingFailedException(String message) {
            super(message);
        }

        public ResourceShrinkingFailedException(String message, Exception e) {
            super(message, e);
        }
    }
}
