/*
 * Copyright 2023 The Bazel Authors. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.google.devtools.build.android.sandboxedsdktoolbox.runtimeenabledsdkconfig;

/**
 * Generator for resource package IDs. This is a prefix byte added to resource IDs.
 *
 * <p>This ID needs to be generated slightly differently based on the minSdkVersion used by the app.
 */
final class ResourceIdGenerator {
  private static final int BASE_RESOURCE_ID = 0x7F;
  private static final int ANDROID_O_SDK_VERSION = 26;

  private final int minSdkVersion;
  private int currentResourceId;

  ResourceIdGenerator(int minSdkVersion) {
    this.minSdkVersion = minSdkVersion;
    if (isOlderThanAndroidO()) {
      currentResourceId = BASE_RESOURCE_ID - 1;
    } else {
      currentResourceId = BASE_RESOURCE_ID + 1;
    }
  }

  int maxResourceIds() {
    // Mirrors Android Gradle Plugin implementation of resource IDs for splits:
    // https://cs.android.com/android-studio/platform/tools/base/+/mirror-goog-studio-main:build-system/gradle-core/src/main/java/com/android/build/gradle/internal/tasks/featuresplit/FeatureSetMetadata.kt;drc=b1afd3d7dfa38875ff7950b65bd58f6a79e74374
    return isOlderThanAndroidO() ? 50 : 127;
  }

  int nextResourceId() {
    if (isOlderThanAndroidO()) {
      return currentResourceId--;
    }
    return currentResourceId++;
  }

  private boolean isOlderThanAndroidO() {
    return minSdkVersion < ANDROID_O_SDK_VERSION;
  }
}
