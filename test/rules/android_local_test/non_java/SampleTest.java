/**
 * Copyright 2021 The Bazel Authors. All rights reserved.
 *
 * <p>Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of the License at
 *
 * <p>http://www.apache.org/licenses/LICENSE-2.0
 *
 * <p>Unless required by applicable law or agreed to in writing, software distributed under the
 * License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.starlark_resources;

import static org.junit.Assert.assertEquals;

import android.content.Context;
import android.content.res.Resources;
import androidx.test.core.app.ApplicationProvider;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class SampleTest {
  private Context targetContext;
  private Resources resources;

  @Before
  public void setup() throws Exception {
    targetContext = ApplicationProvider.getApplicationContext();
    resources = targetContext.getResources();
  }

  @Test
  public void test() throws Exception {
    assertEquals("Check package name", "com.starlark_resources", targetContext.getPackageName());
    assertEquals(
        "Check resource `a_string`", "Hello World!", resources.getString(R.string.a_string));
  }
}
