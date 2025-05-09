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
package com.android.build.gradle.tasks;

import com.android.ide.common.resources.usage.ResourceUsageModel;
import com.android.ide.common.resources.usage.ResourceUsageModel.Resource;
import java.util.List;

/** A stub version of the ResourceUsageAnalyzer class from AOSP.
 * 
 * Note: The real version of this class was deleted from AOSP in 2023.
 * This class is essentially unused in rules_android, since R8 now handles
 * resource shrinking.
 */
public class ResourceUsageAnalyzer {
    public ResourceUsageAnalyzer(Object... args) {}
    public void shrink(Object o) {}
    public ResourceShrinkerUsageModel model() {
        return null;
    }
    public void recordClassUsages(Object o) {}
    public void keepPossiblyReferencedResources() {}
    public void addDeclaredResource(Object... args) {}
    public void getResource(int i) {}
    protected class ResourceShrinkerUsageModel extends ResourceUsageModel {
    }
}