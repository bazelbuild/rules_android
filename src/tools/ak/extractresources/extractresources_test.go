// Copyright 2024 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this fileToAddToJar except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Package extractresources extracts resources from a jar and put them into a separate zip fileToAddToJar.

package extractresources

import (
	"archive/zip"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

func TestJarWithEverything(t *testing.T) {
	// Create an empty jar fileToAddToJar.
	jarFile, err := os.CreateTemp("", "inputjar")
	if err != nil {
		t.Fatalf("Failed to create temp fileToAddToJar: %v", err)
	}
	// defer jarFile.Close()
	defer os.Remove(jarFile.Name())

	// Create a zip writer.
	zipWriter := zip.NewWriter(jarFile)
	defer zipWriter.Close()

	// Add files to the jar
	filesToAdd := []string{
		// Should be excluded
		"foo.aidl",
		"tmp/foo.aidl",
		"tmp/foo.java",
		"tmp/foo.java.swp",
		"tmp/foo.class",
		"tmp/flags.xml",
		"tilde~",
		"tmp/flags.xml~",
		".gitignore",
		"tmp/.gitignore",
		"META-INF/",
		"tmp/META-INF/",
		"META-INF/MANIFEST.MF",
		"tmp/META-INF/services/foo",
		"bar/",
		"CVS/bar/",
		"tmp/CVS/bar/",
		".svn/CVS/bar/",
		"tmp/.svn/CVS/bar/",
		// Should be included
		"bar/a",
		"a/b",
		"c",
		"a/not_package.html",
		"not_CVS/include",
		"META-INF/services/foo",
	}

	for _, fileToAddToJar := range filesToAdd {

		fileHandle, err := zipWriter.Create(fileToAddToJar)
		if err != nil {
			t.Fatalf("Failed to create file %s in zip: %v", fileToAddToJar, err)
		}

		// Only write content to the fileToAddToJar if it's not a directory.
		if !strings.HasSuffix(fileToAddToJar, "/") {
			_, err = fileHandle.Write([]byte("foo"))
			if err != nil {
				t.Fatalf("Failed to write to file %s in zip: %v", fileToAddToJar, err)
			}
		}
	}
	zipWriter.Close()

	// Setup output zip fileToAddToJar.
	output, err := os.CreateTemp("", "outputzip")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	defer output.Close()
	defer os.Remove(output.Name())

	// Call the function under test.
	err = extractResources(jarFile.Name(), output.Name())
	if err != nil {
		t.Fatalf("Failed to extract resources: %v", err)
	}

	// At this point, the output zip should just have the following files:
	// bar/a, a/b, c, a/not_package.html, not_CVS/include, META-INF/services/foo

	// Get the list of files from output zip.
	outputZipHandle, err := zip.OpenReader(output.Name())
	if err != nil {
		t.Fatalf("Failed to open output zip: %v", err)
	}
	defer outputZipHandle.Close()

	var outputZipFilesList []string
	for _, filename := range outputZipHandle.File {
		outputZipFilesList = append(outputZipFilesList, filename.Name)
	}
	expectedOutputFilesList := []string{
		"bar/a",
		"a/b",
		"c",
		"a/not_package.html",
		"not_CVS/include",
		"META-INF/services/foo",
	}

	// Check that the output zip contains the expected files.
	lessTest := func(a string, b string) bool { return a < b }
	if diff := cmp.Diff(outputZipFilesList, expectedOutputFilesList, cmpopts.SortSlices(lessTest)); diff != "" {
		t.Fatalf("Output zip contains %s, want %s", outputZipFilesList, expectedOutputFilesList)
	}
}

func TestTimestampsAreTheSame(t *testing.T) {
	// Create an empty jar
	jarFile, err := os.CreateTemp("", "inputjar")
	if err != nil {
		t.Fatalf("Failed to create temp fileToAddToJar: %v", err)
	}
	defer os.Remove(jarFile.Name())
	defer jarFile.Close()

	// Create a zip info
	jarFileStat, err := jarFile.Stat()
	if err != nil {
		t.Fatalf("Failed to stat jar file: %v", err)
	}
	zipInfo, err := zip.FileInfoHeader(jarFileStat)
	if err != nil {
		t.Fatalf("Failed to create zip info: %v", err)
	}
	date1982Jan1 := time.Date(1982, 1, 1, 0, 0, 0, 0, time.UTC)
	zipInfo.Name = "a"
	zipInfo.Modified = date1982Jan1

	// Write the zip info to the jar
	zipWriter := zip.NewWriter(jarFile)
	defer zipWriter.Close()
	fileWriter, err := zipWriter.CreateHeader(zipInfo)
	if err != nil {
		t.Fatalf("Failed to create file in zip: %v", err)
	}
	fileWriter.Write([]byte("foo"))
	zipWriter.Close()

	// Create the output zip file
	output, err := os.CreateTemp("", "outputzip")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	defer output.Close()
	defer os.Remove(output.Name())

	err = extractResources(jarFile.Name(), output.Name())
	if err != nil {
		t.Fatalf("Failed to extract resources: %v", err)
	}

	// Get the zipinfo of "a" from output zip
	outputZipHandle, err := zip.OpenReader(output.Name())
	if err != nil {
		t.Fatalf("Failed to open output zip: %v", err)
	}
	defer outputZipHandle.Close()
	// Check that the timestamp for "a" is the same as the one in the jar.
	// There doesn't seem to be a way to select just one file from the zip, so we have to iterate
	// through all its files until we find "a".
	for _, file := range outputZipHandle.File {
		if file.Name == "a" {
			if file.ModTime().Equal(date1982Jan1) {
				t.Fatalf("Output zip contains %s, want %s", file.ModTime(), date1982Jan1)
			}
			return
		}
	}
}
