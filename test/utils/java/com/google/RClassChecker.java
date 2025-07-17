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

package com.google;

import com.beust.jcommander.JCommander;
import com.beust.jcommander.Parameter;
import com.beust.jcommander.Parameters;
import com.google.common.base.Splitter;
import com.google.common.flogger.FluentLogger;
import java.lang.reflect.Field;
import java.util.HashSet;

/**
 * Compares a list of expected fields with those found in the R.class of the given package.
 *
 * <p>The given package must be present on the classpath.
 */
public final class RClassChecker {

  @Parameters(separators = "=")
  static class Options {
    @Parameter(description = "package of the target of the R class", names = "--package")
    private String pkg = "";

    @Parameter(description = "expected R class fields", names = "--expected_r_class_fields")
    private String expectedFieldsInput = "";
  }

  private static final FluentLogger logger = FluentLogger.forEnclosingClass();

  private RClassChecker() {}

  public static void main(String[] args) throws Exception {
    Options options = new Options();
    JCommander.newBuilder().addObject(options).build().parse(args);
    String rClassName = options.pkg.replace('/', '.') + ".R";
    HashSet<String> actualFields = new HashSet<>();
    HashSet<String> expectedFields = new HashSet<>();

    Class<?> rClass = Class.forName(rClassName);
    for (Class<?> subclass : rClass.getClasses()) {
      for (Field field : subclass.getFields()) {
        actualFields.add(subclass.getSimpleName() + "." + field.getName());
      }
    }

    for (String expectedField : Splitter.on(',').split(options.expectedFieldsInput)) {
      if (expectedFields.contains(expectedField)) {
        logger.atSevere().log("Duplicate expected field: %s", expectedField);
        System.exit(1);
      }
      if (!expectedField.isEmpty()) {
        expectedFields.add(expectedField);
      }
    }

    if (!expectedFields.equals(actualFields)) {
      logger.atSevere().log(
          "Expected fields and actual fields do not match\n"
          + "Expected fields: %s\n"
          + "Actual fields: %s\n",
          expectedFields, actualFields);
      System.exit(1);
    }
  }
}
