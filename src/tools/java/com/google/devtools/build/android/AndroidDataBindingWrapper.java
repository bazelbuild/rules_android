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

import android.databinding.AndroidDataBinding;
import android.databinding.cli.ProcessXmlOptions;

/**
 * Wrapper around the AndroidDataBinding.main() method.
 *
 * <p>Used solely to decouple android_builder_lib from directly depending on android.databinding.*.
 */
final class AndroidDataBindingWrapper {

  private AndroidDataBindingWrapper() {}

  public static void main(String[] args) {
    AndroidDataBinding.main(args);
  }

  public static void doRun(ProcessXmlOptionsWrapper options) {
    AndroidDataBinding.doRun((ProcessXmlOptions) options);
  }
}
