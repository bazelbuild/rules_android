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

package repack

import (
	"archive/zip"
	"bytes"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"testing"
)

type test struct {
	name     string
	testData []testData
	filter   filterFunc
}

type testData struct {
	name  string
	match bool
}

var (
	filterNoneData = []testData{
		{
			name:  "META-INF/MANIFEST.MF",
			match: false,
		},
		{
			name:  "com/google/android/test/TestActivity.class",
			match: false,
		},
		{
			name:  "googledata/data.txt",
			match: false,
		},
	}
	filterJarResData = []testData{
		{
			name:  "META-INF/MANIFEST.MF",
			match: false,
		},
		{
			name:  "com/google/android/test/TestActivity.class",
			match: false,
		},
		{
			name:  "googledata/data.txt",
			match: true,
		},
	}
	filterRData = []testData{
		{
			name:  "META-INF/MANIFEST.MF",
			match: false,
		},
		{
			name:  "com/google/android/test/TestActivity.class",
			match: false,
		},
		{
			name:  "com/google/android/test/R.class",
			match: true,
		},
		{
			name:  "com/google/android/test/R$string.class",
			match: true,
		},
		{
			name:  "com/google/android/test/R$attr.class",
			match: true,
		},
	}
	filterManifestData = []testData{
		{
			name:  "AndroidManifest.xml",
			match: true,
		},
		{
			name:  "res/drawable/icon.png",
			match: false,
		},
		{
			name:  "res/layout/skeleton_activity.xml",
			match: false,
		},
		{
			name:  "resources.arsc",
			match: false,
		},
	}
	tests = []test{
		{
			name:     "filterNone",
			testData: filterNoneData,
			filter:   filterNone,
		},
		{
			name:     "isJavaRes",
			testData: filterJarResData,
			filter:   isJavaRes,
		},
		{
			name:     "isRClass",
			testData: filterRData,
			filter:   isRClass,
		},
		{
			name:     "isManifest",
			testData: filterManifestData,
			filter:   isManifest,
		},
	}
)

func TestRepackZip(t *testing.T) {
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			bufIn := new(bytes.Buffer)
			zipIn := zip.NewWriter(bufIn)
			createZip(zipIn, test.testData)

			if err := zipIn.Close(); err != nil {
				log.Fatal(err)
			}

			inReader, err := zip.NewReader(bytes.NewReader(bufIn.Bytes()), int64(bufIn.Len()))
			if err != nil {
				t.Fatal(err)
			}

			in := &zip.ReadCloser{
				Reader: *inReader,
			}

			repackZipTest(t, in, test)
			repackZipWithFiletedOutTest(t, in, test)
		})
	}
}

func TestFilterZip(t *testing.T) {
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			for _, testData := range test.testData {
				if test.filter(testData.name) != testData.match {
					t.Errorf("Filter applied on: %q got: %v wanted: %v", testData.name, test.filter(testData.name), testData.match)
				}
			}
		})
	}
}

func TestRepackDir(t *testing.T) {
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			dir, err := ioutil.TempDir("", "repack_dir_")
			if err != nil {
				log.Fatal(err)
			}
			defer os.RemoveAll(dir)

			createDir(dir, test.testData)
			repackDirTest(t, dir, test)
		})
	}
}

func repackZipTest(t *testing.T, in *zip.ReadCloser, test test) {
	bufOut := new(bytes.Buffer)
	zipOut := zip.NewWriter(bufOut)

	seen = make(map[string]bool)
	if err := repackZip(&in.Reader, zipOut, nil, test.filter, zip.Store); err != nil {
		t.Fatal(err)
	}

	if err := zipOut.Close(); err != nil {
		log.Fatal(err)
	}

	r, err := zip.NewReader(bytes.NewReader(bufOut.Bytes()), int64(bufOut.Len()))
	if err != nil {
		t.Fatal(err)
	}

	files := []string{}
	for _, testData := range test.testData {
		if !testData.match {
			files = append(files, testData.name)
		}
	}

	if len(r.File) != len(files) {
		t.Fatalf("Output file number differ, got: %v wanted: %v", len(r.File), len(files))
	}

	for i, fileName := range files {
		if r.File[i].Name != fileName {
			t.Errorf("Filename differ, got: %q wanted: %q", r.File[i].Name, fileName)
		}
	}
}

func repackZipWithFiletedOutTest(t *testing.T, in *zip.ReadCloser, test test) {
	bufOut := new(bytes.Buffer)
	zipOut := zip.NewWriter(bufOut)

	buffilteredOut := new(bytes.Buffer)
	zipfilteredOut := zip.NewWriter(buffilteredOut)

	seen = make(map[string]bool)
	if err := repackZip(&in.Reader, zipOut, zipfilteredOut, test.filter, zip.Store); err != nil {
		t.Fatal(err)
	}

	if err := zipOut.Close(); err != nil {
		log.Fatal(err)
	}
	if err := zipfilteredOut.Close(); err != nil {
		log.Fatal(err)
	}

	r, err := zip.NewReader(bytes.NewReader(bufOut.Bytes()), int64(bufOut.Len()))
	if err != nil {
		t.Fatal(err)
	}
	rfiltered, err := zip.NewReader(bytes.NewReader(buffilteredOut.Bytes()), int64(buffilteredOut.Len()))
	if err != nil {
		t.Fatal(err)
	}

	files := []string{}
	filesfiltered := []string{}
	for _, testData := range test.testData {
		if !testData.match {
			files = append(files, testData.name)
		} else {
			filesfiltered = append(filesfiltered, testData.name)
		}
	}

	if len(r.File) != len(files) {
		t.Fatalf("Output file number differ, got: %v wanted: %v", len(r.File), len(files))
	}

	if len(rfiltered.File) != (len(filesfiltered)) {
		t.Fatalf("Filtered output file number differ, got: %v wanted: %v", len(rfiltered.File), len(files))
	}

	for i, fileName := range files {
		if r.File[i].Name != fileName {
			t.Errorf("Filename differ, got: %q wanted: %q", r.File[i].Name, fileName)
		}
	}

	for i, fileName := range filesfiltered {
		if rfiltered.File[i].Name != fileName {
			t.Errorf("Filtered filename differ, got: %q wanted: %q", rfiltered.File[i].Name, fileName)
		}
	}
}

func repackDirTest(t *testing.T, dir string, test test) {
	removeDirs = true
	bufOut := new(bytes.Buffer)
	zipOut := zip.NewWriter(bufOut)

	seen = make(map[string]bool)
	if err := repackDir(dir, zipOut, nil, test.filter, zip.Store); err != nil {
		log.Fatal(err)
	}

	if err := zipOut.Close(); err != nil {
		log.Fatal(err)
	}

	r, err := zip.NewReader(bytes.NewReader(bufOut.Bytes()), int64(bufOut.Len()))
	if err != nil {
		t.Fatal(err)
	}

	files := []string{}
	for _, testData := range test.testData {
		if !testData.match {
			files = append(files, testData.name)
		}
	}

	if len(r.File) != len(files) {
		t.Fatalf("Output file number differ, got: %v wanted: %v", len(r.File), len(files))
	}

	for i, fileName := range files {
		if r.File[i].Name != fileName {
			t.Errorf("Filename differ, got: %q wanted: %q", r.File[i].Name, fileName)
		}
	}
}

func createZip(w *zip.Writer, testDatas []testData) {
	for _, testData := range testDatas {
		f, err := w.Create(testData.name)
		if err != nil {
			log.Fatal(err)
		}
		_, err = f.Write([]byte{42})
		if err != nil {
			log.Fatal(err)
		}
	}
}

func createDir(base string, testDatas []testData) {
	for _, testData := range testDatas {
		path := filepath.Join(base, testData.name)
		if err := os.MkdirAll(filepath.Dir(path), 0777); err != nil {
			log.Fatal(err)
		}
		if err := ioutil.WriteFile(path, []byte{1, 2, 3}, 0777); err != nil {
			log.Fatal(err)
		}
	}
}
