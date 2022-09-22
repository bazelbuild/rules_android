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

package nativelib

import (
	"archive/zip"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"testing"
)

const (
	expectedName = "lib/x86/dummy.so"
	dummyLib     = "src/tools/ak/nativelib/testdata/dummy.so"
)

func makeLibZip(t *testing.T, entry io.Reader, entryName, zipPath string) error {
	f, err := os.Create(zipPath)
	if err != nil {
		return err
	}
	defer func() {
		if err := f.Close(); err != nil {
			t.Error(err)
		}
	}()

	archive := zip.NewWriter(f)
	wr, err := archive.CreateHeader(&zip.FileHeader{Name: entryName, Method: zip.Store})
	if err != nil {
		return err
	}
	if _, err := io.Copy(wr, entry); err != nil {
		return err
	}
	return archive.Close()
}

func TestCreateNativeLibZip(t *testing.T) {
	tmpDir, err := ioutil.TempDir("", "shelltest")
	if err != nil {
		t.Fatalf("Error creating temp directory: %v", err)
	}
	defer os.RemoveAll(tmpDir)
	out := filepath.Join(tmpDir, "lib.zip")
	in := []string{"x86:" + path.Join(os.Getenv("TEST_SRCDIR"), dummyLib)}
	if err := doWork(in, out); err != nil {
		t.Fatalf("Error creating native lib zip: %v", err)
	}

	z, err := zip.OpenReader(out)
	if err != nil {
		t.Fatalf("Error opening output zip: %v", err)
	}
	defer z.Close()

	if len(z.File) != 1 {
		t.Fatalf("Got %d files in zip, expected 1", len(z.File))
	}

	if z.File[0].Name != expectedName {
		t.Fatalf("Got .so file %s, expected %s", z.File[0].Name, expectedName)
	}
}

func TestExtractLibs(t *testing.T) {
	tmpDir, err := ioutil.TempDir("", "shelltest")
	if err != nil {
		t.Fatalf("Error creating temp directory: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	lib, err := os.Create(filepath.Join(tmpDir, "dmmylib.so"))
	if err != nil {
		t.Fatalf("Error creating dummy lib: %v", err)
	}

	libZip := filepath.Join(tmpDir, "libs.zip")
	if err := makeLibZip(t, lib, expectedName, libZip); err != nil {
		t.Fatalf("error creating aar lib zip: %v", err)
	}

	dstDir, err := ioutil.TempDir("", "ziplibs")
	if err != nil {
		t.Fatalf("Error extracting creating zip dir: %v", err)
	}
	defer os.RemoveAll(dstDir)

	libs, err := extractLibs(libZip, dstDir)
	if err != nil {
		t.Fatalf("Error extracting libs from zip: %v", err)
	}

	if len(libs) != 1 {
		t.Fatalf("Got %d files in zip, expected 1", len(libs))
	}
	expected := fmt.Sprintf("x86:%s", filepath.Join(dstDir, "lib/x86/dummy.so"))
	if libs[0] != expected {
		t.Fatalf("Got %s lib, expected %s", libs[0], expected)
	}

}
