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

package com.neverlink;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;

/** The main activity of the Basic Sample App. */
public class BasicActivity extends Activity {

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    // Neverlink1 and Neverlink2 are neverlink dependencies, so these lines should compile
    // but these classes shouldn't be in the final apk (which means that this app won't run,
    // but it's good enough to test the build).
    Log.i("tag", String.valueOf(Neverlink1.getValue(21)));
    Log.i("tag", String.valueOf(Neverlink2.getValue(21)));
  }
}
