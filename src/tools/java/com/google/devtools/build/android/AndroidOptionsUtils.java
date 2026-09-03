// Copyright 2024 The Bazel Authors. All rights reserved.
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


import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;
import com.beust.jcommander.ParameterException;
import com.google.common.base.Preconditions;
import com.google.common.collect.ImmutableList;
import java.lang.annotation.Annotation;
import java.lang.reflect.Field;
import java.nio.file.FileSystem;
import java.nio.file.FileSystems;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** Utility class for JCommander-based Android options. */
public class AndroidOptionsUtils {

  private AndroidOptionsUtils() {}

  /** Run the CompatShellQuotedParamsFilePreProcessor on a list of args. */
  public static String[] runArgFilePreprocessor(JCommander jc, String[] argsAsArray) {
    jc.setExpandAtSign(false);
    return runArgFilePreprocessor(argsAsArray);
  }

  /** Run the CompatShellQuotedParamsFilePreProcessor on a list of args. */
  public static String[] runArgFilePreprocessor(String[] argsAsArray) {
    List<String> args = ImmutableList.copyOf(argsAsArray);
    if (args.size() == 1 && args.get(0).startsWith("@")) {
      // Use CompatShellQuotedParamsFilePreProcessor to handle the arg file.
      FileSystem fs = FileSystems.getDefault();
      Path argFile = fs.getPath(args.get(0).substring(1));
      CompatShellQuotedParamsFilePreProcessor paramsFilePreProcessor =
          new CompatShellQuotedParamsFilePreProcessor(fs);
      args = paramsFilePreProcessor.preProcess(ImmutableList.of("@" + argFile));
    }
    return args.toArray(new String[0]);
  }

  private static int countLeadingChars(String s, char c) {
    int count = 0;
    for (int i = 0; i < s.length(); i++) {
      if (s.charAt(i) != c) {
        break;
      }
      count++;
    }
    return count;
  }

  /**
   * Same as AndroidOptionsUtils#normalizeBooleanOptions, but accepts an array of option classes
   * instead.
   */
  public static String[] normalizeBooleanOptions(Object[] options, String[] args) {
    String[] normalizedArgs = args;
    for (Object optionsObject : options) {
      normalizedArgs = normalizeBooleanOptions(optionsObject, normalizedArgs);
    }
    return normalizedArgs;
  }

  /**
   * Normalize boolean options to use --<flagname>=true or --<flagname>=false syntax.
   *
   * <p>This is useful for JCommander-based options.
   */
  public static String[] normalizeBooleanOptions(Object options, String[] args) {
    Set<String> booleanOptionNames = new HashSet<>();
    // Find the list of boolean fields
    for (Field field : options.getClass().getDeclaredFields()) {
      if (field.getType().equals(boolean.class)) {
        // Get the `names` from the annotation of this field.
        // Iterate through the annotations
        for (Annotation annotation : field.getAnnotations()) {
          if (annotation instanceof Parameter parameter) {
            for (String name : parameter.names()) {
              // Strip leading dashes from the name and assert that the name starts with --.
              try {
                Preconditions.checkState(name.startsWith("--") || name.startsWith("-"));
                booleanOptionNames.add(name.substring(countLeadingChars(name, '-')));
              } catch (IllegalStateException e) {
                throw new ParameterException(
                    "ParameterException in args: Found an arg not prefixed with '--' or '-': '"
                        + name
                        + "'. Exception message: "
                        + e.getMessage());
              }
            }
          }
        }
      }
    }

    Map<String, String> replacements = new HashMap<>();
    for (String booleanOption : booleanOptionNames) {
      replacements.put("--no" + booleanOption, "--" + booleanOption + "=false");
      replacements.put("--" + booleanOption, "--" + booleanOption + "=true");
    }

    // Iterate through the args and normalize boolean options with --<flagname> syntax.
    String[] normalizedArgs = new String[args.length];
    for (int i = 0; i < args.length; i++) {
      String arg = args[i];
      String replacement = replacements.get(arg);
      normalizedArgs[i] = replacement != null ? replacement : arg;
    }
    return normalizedArgs;
  }
}
