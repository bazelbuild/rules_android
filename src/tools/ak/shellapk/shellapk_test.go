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

package shellapk

import (
	"archive/zip"
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"strings"
	"testing"
)

const (
	testDataBase = "src/tools/ak/shellapk/testdata"
	pkgName      = "com.example"
	appName      = "com.example.ExampleApplication"
)

func TestCreateShellApk(t *testing.T) {
	tmpDir, err := ioutil.TempDir("", "shelltest")
	if err != nil {
		t.Fatalf("Error creating temp directory: %v", err)
	}
	defer os.RemoveAll(tmpDir)
	out := filepath.Join(tmpDir, "shell.apk")
	res := dataPath("res.zip")
	nativeLib := dataPath("native_lib.zip")
	jdk := strings.Split(os.Getenv("JAVA_HOME"), "/bin/")[0]
	dexFile := dataPath("dexes.zip")
	manifestPkgName := dataPath("manifest_package_name.txt")
	inAppClassName := dataPath("app_name.txt")
	manifest := dataPath("AndroidManifest.xml")
	err = doWork(
		out,
		[]string{res},
		nativeLib,
		jdk,
		dexFile,
		manifestPkgName,
		inAppClassName,
		manifest,
		"", // arsc
		res,
		"") // linkedNativeLib
	if err != nil {
		t.Fatalf("Error creating shell apk: %v", err)
	}

	if _, err := os.Stat(out); os.IsNotExist(err) {
		t.Fatalf("Shell apk not created")
	}

	z, err := zip.OpenReader(out)
	if err != nil {
		t.Fatalf("Error opening output apk: %v", err)
	}
	defer z.Close()

	if !zipContains(z, "AndroidManifest.xml") {
		t.Fatalf("APK does not contain AndroidManifest.xml")
	}
	if !zipContains(z, "classes.dex") {
		t.Fatalf("APK does not contain classes.dex")
	}
	if !zipContains(z, "lib/x86/libsample.so") {
		t.Fatalf("APK does not contain native lib")
	}

	c, err := zipFileContents(z, "package_name.txt")
	if err != nil {
		t.Fatalf("Error opening package_name.txt: %v", err)
	}
	if c != pkgName {
		t.Fatalf("package_name.txt invalid content. Got (%v) expected (%v)", c, pkgName)
	}

	c, err = zipFileContents(z, "app_name.txt")
	if err != nil {
		t.Fatalf("Error opening app_name.txt")
	}
	if c != appName {
		t.Fatalf("app_name.txt invalid content. Got (%v) expected (%v)", c, appName)
	}

	resZip, err := zip.OpenReader(res)
	if err != nil {
		t.Fatalf("Error opening res zip: %v", err)
	}
	defer resZip.Close()
	for _, f := range z.File {
		if !zipContains(z, f.Name) {
			t.Fatalf("APK does not contain resource %s", f.Name)
		}
	}
}

func dataPath(fn string) string {
	return path.Join(os.Getenv("TEST_SRCDIR"), testDataBase, fn)
}

func zipContains(z *zip.ReadCloser, fn string) bool {
	for _, f := range z.File {
		if fn == f.Name {
			return true
		}
	}
	return false
}

func zipFileContents(z *zip.ReadCloser, fn string) (string, error) {
	for _, f := range z.File {
		if fn == f.Name {
			rc, err := f.Open()
			if err != nil {
				return "", err
			}
			contents, err := ioutil.ReadAll(rc)
			if err != nil {
				return "", err
			}
			return string(contents), nil
		}
	}
	return "", fmt.Errorf("Zip does not contain file")
}
