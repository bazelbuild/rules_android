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

import com.android.ide.common.xml.AndroidManifestParser;
import com.android.ide.common.xml.ManifestData;
import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;
import com.beust.jcommander.Parameters;
import com.google.common.base.Preconditions;
import com.google.common.base.Strings;
import com.google.devtools.build.android.Converters.CompatExistingPathConverter;
import com.google.devtools.build.android.Converters.CompatPathConverter;
import com.google.devtools.build.android.Converters.CompatUnvalidatedAndroidDirectoriesConverter;
import com.google.devtools.build.android.aapt2.Aapt2ConfigOptions;
import com.google.devtools.build.android.aapt2.CompiledResources;
import com.google.devtools.build.android.aapt2.ResourceCompiler;
import org.xml.sax.SAXException;

import javax.xml.parsers.ParserConfigurationException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.ExecutionException;
import java.util.logging.Logger;

/** Compiles resources using aapt2 and archives them to zip. */
@Parameters(separators = "= ")
public class CompileLibraryResourcesAction {
  /** Flag specifications for this action. */
  public static final class Options {

    @Parameter(
        names = "--packageForR",
        description = "Custom java package to generate the R symbols files.")
    public String packageForR;

    @Parameter(
        names = "--resources",
        converter = CompatUnvalidatedAndroidDirectoriesConverter.class,
        description = "The resources to compile with aapt2.")
    public UnvalidatedAndroidDirectories resources;

    @Parameter(
        names = "--output",
        converter = CompatPathConverter.class,
        description = "Path to write the zip of compiled resources.")
    public Path output;

    @Parameter(
        names = "--packagePath",
        description =
            "The package path of the library being processed."
                + " This value is required for processing data binding.")
    public String packagePath;

    @Parameter(
        names = "--manifest",
        converter = CompatExistingPathConverter.class,
        description =
            "The manifest of the library being processed."
                + " This value is required for processing data binding.")
    public Path manifest;

    @Parameter(
        names = "--dataBindingInfoOut",
        converter = CompatPathConverter.class,
        description =
            "Path for the derived data binding metadata."
                + " This value is required for processing data binding.")
    public Path dataBindingInfoOut;

    @Parameter(
        names = "--targetLabel",
        description = "A label to add to the output jar's manifest as 'Target-Label'")
    public String targetLabel;

    @Parameter(
        names = "--injectingRuleKind",
        description = "A string to add to the output jar's manifest as 'Injecting-Rule-Kind'")
    public String injectingRuleKind = null;

    @Parameter(
        names = "--classJarOutput",
        converter = CompatPathConverter.class,
        description = "Path to write the jar containing the R classes.")
    public Path classJarOutput = null;

    @Parameter(
        names = "--rTxtOut",
        converter = CompatPathConverter.class,
        description = "Path to write the R.txt file.")
    public Path rTxtOut = null;
  }

  static final Logger logger = Logger.getLogger(CompileLibraryResourcesAction.class.getName());

  public static void main(String[] args) throws Exception {
    Options options = new Options();
    Aapt2ConfigOptions aapt2Options = new Aapt2ConfigOptions();
    Object[] allOptions = {options, aapt2Options, new ResourceProcessorCommonOptions()};
    JCommander jc = new JCommander(allOptions);
    String[] preprocessedArgs = AndroidOptionsUtils.runArgFilePreprocessor(jc, args);
    String[] normalizedArgs =
        AndroidOptionsUtils.normalizeBooleanOptions(allOptions, preprocessedArgs);
    jc.parse(normalizedArgs);

    Preconditions.checkNotNull(options.resources);
    Preconditions.checkNotNull(options.output);
    Preconditions.checkNotNull(aapt2Options.aapt2);

    try (ExecutorServiceCloser executorService = ExecutorServiceCloser.createWithFixedPoolOf(15);
        ScopedTemporaryDirectory scopedTmp =
            new ScopedTemporaryDirectory("android_resources_tmp")) {
      final Path tmp = scopedTmp.getPath();
      final Path databindingResourcesRoot =
          Files.createDirectories(tmp.resolve("android_data_binding_resources"));
      final Path compiledResources = Files.createDirectories(tmp.resolve("compiled"));

      final ResourceCompiler compiler =
          ResourceCompiler.create(
              executorService,
              compiledResources,
              aapt2Options.aapt2,
              aapt2Options.buildToolsVersion,
              aapt2Options.generatePseudoLocale,
              aapt2Options.useAapt2Cruncher != TriState.NO);
      options
          .resources
          .toData(options.manifest)
          .processDataBindings(
              options.dataBindingInfoOut,
              options.packagePath,
              databindingResourcesRoot,
              aapt2Options.useDataBindingAndroidX)
          .compile(compiler, compiledResources)
          .copyResourcesZipTo(options.output);

      if (options.rTxtOut != null && options.classJarOutput != null) {
        generateRFiles(options, aapt2Options, tmp);
      }
    } catch (IOException | ExecutionException | InterruptedException e) {
      logger.log(java.util.logging.Level.SEVERE, "Unexpected", e);
      throw e;
    }
  }

  /** Generates namespaced R.class + R.txt */
  private static void generateRFiles(Options options, Aapt2ConfigOptions aapt2Options, Path tmp)
      throws IOException {
    Path generatedSources = tmp.resolve("generated_resources");

    Preconditions.checkArgument(
        options.manifest != null || options.packageForR != null,
        "To generate R files, either a package or manifest must be specified");
    String packageForR = options.packageForR;
    if (packageForR == null) {
      try {
        ManifestData manifestData =
            AndroidManifestParser.parse(Files.newInputStream(options.manifest));
        packageForR = Strings.nullToEmpty(manifestData.getPackage());
      } catch (ParserConfigurationException | SAXException e) {
        packageForR = "";
      }
    }

    AndroidResourceClassWriter resourceClassWriter =
        AndroidResourceClassWriter.createWith(
            options.targetLabel, aapt2Options.androidJar, generatedSources, packageForR);
    resourceClassWriter.setIncludeClassFile(true);
    resourceClassWriter.setIncludeJavaFile(false);

    PlaceholderRTxtWriter rTxtWriter = PlaceholderRTxtWriter.create(options.rTxtOut);

    SerializedAndroidData primary =
        SerializedAndroidData.from(CompiledResources.from(options.output));

    final ParsedAndroidData.Builder primaryBuilder = ParsedAndroidData.Builder.newBuilder();

    final AndroidDataDeserializer deserializer =
        AndroidCompiledDataDeserializer.create(/* includeFileContentsForValidation= */ false);
    primary.deserialize(
        DependencyInfo.DependencyType.PRIMARY, deserializer, primaryBuilder.consumers());

    ParsedAndroidData primaryData = primaryBuilder.build();
    primaryData.writeResourcesTo(resourceClassWriter);
    primaryData.writeResourcesTo(rTxtWriter);
    resourceClassWriter.flush();
    rTxtWriter.flush();

    AndroidResourceOutputs.createClassJar(
        generatedSources, options.classJarOutput, options.targetLabel, options.injectingRuleKind);
  }
}
