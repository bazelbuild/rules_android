// Copyright 2018 The Bazel Authors. All rights reserved.
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

package rjar

import (
	"archive/zip"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"testing"
)

var (
	expectedClasses = []string{"R.class", "R$attr.class", "R$id.class", "R$layout.class", "R$string.class"}
)

const (
	java         = "local_jdk/bin/java"
	testDataBase = "build_bazel_rules_android/src/tools/ak/rjar/testdata"
)

func TestCreateRJar(t *testing.T) {
	tmpDir, err := ioutil.TempDir("", "rjartest")
	if err != nil {
		t.Fatalf("Error creating temp directory: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	out := filepath.Join(tmpDir, "R.jar")
	jarDexer := path.Join(os.Getenv("TEST_SRCDIR"), "remote_java_tools_for_rules_android/java_tools/JavaBuilder_deploy.jar")
	inJava := dataPath("R.java")
	pkgs := dataPath("pkgs.txt")
	targetLabel := "//test:test"

	if err := doWork(inJava, pkgs, out, path.Join(os.Getenv("TEST_SRCDIR"), java), jarDexer, targetLabel); err != nil {
		t.Fatalf("Error creating R.jar: %v", err)
	}

	z, err := zip.OpenReader(out)
	if err != nil {
		t.Fatalf("Error opening output jar: %v", err)
	}
	defer z.Close()

	for _, class := range expectedClasses {
		if !zipContains(z, filepath.Join("android/support/v7", class)) {
			t.Errorf("R.jar does not contain %s", filepath.Join("android/support/v7", class))
		}
		if !zipContains(z, filepath.Join("com/google/android/samples/skeletonapp", class)) {
			t.Errorf("R.jar does not contain %s", filepath.Join("com/google/android/samples/skeletonapp", class))
		}
		if zipContains(z, filepath.Join("com/google/android/package/test", class)) {
			t.Errorf("R.jar contains %s", filepath.Join("com/google/android/package/test", class))
		}
	}
}

func dataPath(fn string) string {
	return filepath.Join(os.Getenv("TEST_SRCDIR"), testDataBase, fn)
}

func zipContains(z *zip.ReadCloser, fn string) bool {
	for _, f := range z.File {
		if fn == f.Name {
			return true
		}
	}
	return false
}
