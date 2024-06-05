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

// Package extractresources extracts resources from a jar and put them into a separate zip file.
package extractresources

import (
	"archive/zip"
	"io"
	"os"
	"slices"
	"strings"
	"sync"

	"log"

	"src/tools/ak/types"
)

var (
	// Cmd defines the command.
	Cmd = types.Command{
		Init:  Init,
		Run:   Run,
		Desc:  desc,
	}
	initOnce           sync.Once
	excludedExtensions = []string{
		".aidl",                // Android interface definition files
		".rs",                  // RenderScript files
		".fs",                  // FilterScript files
		".rsh",                 // RenderScript header files
		".d",                   // Dependency files
		".java",                // Java source files
		".scala",               // Scala source files
		".class",               // Java class files
		".scc",                 // Visual SourceSafe
		".swp",                 // vi swap file
		".gwt.xml",             // Google Web Toolkit modules
		"~",                    // backup files
		"/",                    // empty directory entries
		".autodepsmetadata.pb", // auto deps metadata
	}

	excludedFilenames = []string{
		"thumbs.db",     // image index file
		"picasa.ini",    // image index file
		"package.html",  // Javadoc
		"overview.html", // Javadoc
		"protobuf.meta", // protocol buffer metadata
		"flags.xml",     // Google flags metadata
	}

	excludedDirectories = []string{
		"cvs",      // CVS repository files
		".svn",     // SVN repository files
		"sccs",     // SourceSafe repository files
		"meta-inf", // jar metadata
	}
)

func desc() string {
	return "Extracts resources from a jar and put them into a separate zip file."
}

// Init initializes extractresources action.
func Init() {
	// Empty placeholder function. Will get segfaults in ak if this doesn't exist.
}

// shouldExtractFile  checks if the provided path describes a resource, and should be extracted.
func shouldExtractFile(path string) bool {
	path = strings.ToLower(path)
	for _, ext := range excludedExtensions {
		if strings.HasSuffix(path, ext) {
			return false
		}
	}

	segments := strings.Split(path, "/")
	filename := segments[len(segments)-1]
	if strings.HasPrefix(filename, ".") || slices.Contains(excludedFilenames, filename) {
		return false
	}

	dirs := segments[:len(segments)-1]
	// allow META-INF/services at the root to support ServiceLoader
	if len(dirs) >= 2 && dirs[0] == "meta-inf" && dirs[1] == "services" {
		return true
	}

	// Check that no parts of the parent directory path should be excluded.
	for _, dir := range excludedDirectories {
		if slices.Contains(dirs, dir) {
			return false
		}
	}

	return true
}

func extractResources(inputJarFilename string, outputZipFilename string) error {
	// Input jar reader setup
	inputJar, err := zip.OpenReader(inputJarFilename)
	if err != nil {
		return err
	}
	defer inputJar.Close()

	// Output zip writer setup
	outputZipFile, err := os.Create(outputZipFilename)
	if err != nil {
		return err
	}
	defer outputZipFile.Close()
	outputZipWriter := zip.NewWriter(outputZipFile)
	defer outputZipWriter.Close()

	for _, fileInZip := range inputJar.File {
		if shouldExtractFile(fileInZip.Name) {
			// Write the file to the output zip file.
			fileHandle, err := outputZipWriter.CreateHeader(&zip.FileHeader{
				Name:   fileInZip.Name,
				Method: zip.Store, // Don't use any compression, since the legacy tool did not.
			})
			if err != nil {
				return err
			}
			fileInZipHandle, err := fileInZip.Open()
			if err != nil {
				return err
			}
			_, err = io.Copy(fileHandle, fileInZipHandle)
			if err != nil {
				return err
			}
		}
	}

	return nil
}

// Run is the main entry point for the extractresources binary.
func Run() {
	// Args will be in the form of `ak extractresources input_jar output_zip`
	if len(os.Args) != 4 {
		log.Fatal("Usage: ak extractresources input_jar output_zip")
	}
	inputJarFilename := os.Args[2]
	outputZipFilename := os.Args[3]
	if err := extractResources(inputJarFilename, outputZipFilename); err != nil {
		log.Fatal(err)
	}
}
