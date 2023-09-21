// Copyright 2023 The Bazel Authors. All rights reserved.
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

// Tool for building Bundletool modules for apps and SDKs.
package main

import (
	"archive/zip"
	"flag"
	"log"
	"os"
	"strings"
)

var (
	internalApkPathFlag  = flag.String("internal_apk_path", "", "Path to an APK that contains the SDK classes and resources.")
	outputModulePathFlag = flag.String("output_module_path", "", "Path to the resulting module, ready to be sent to Bundletool.")
)

func main() {
	flag.Parse()
	if *internalApkPathFlag == "" {
		log.Fatal("Missing internal APK path")
	}

	if *internalApkPathFlag == "" {
		log.Fatal("Missing ouput module path")
	}
	err := unzipApkAndCreateModule(*internalApkPathFlag, *outputModulePathFlag)
	if err != nil {
		log.Fatal(err)
	}
}

func unzipApkAndCreateModule(internalApkPath, outputModulePath string) error {
	r, err := zip.OpenReader(internalApkPath)
	if err != nil {
		return err
	}
	defer r.Close()

	w, err := os.Create(outputModulePath)
	if err != nil {
		return err
	}
	defer w.Close()
	zipWriter := zip.NewWriter(w)
	defer zipWriter.Close()

	for _, f := range r.File {
		f.Name = fileNameInOutput(f.Name)
		if err := zipWriter.Copy(f); err != nil {
			return err
		}
	}
	return nil
}

func fileNameInOutput(oldName string) string {
	switch {
	// Passthrough files. They will just be copied into the output module.
	case oldName == "resources.pb" ||
		strings.HasPrefix(oldName, "res/") ||
		strings.HasPrefix(oldName, "assets/") ||
		strings.HasPrefix(oldName, "lib/"):
		return oldName
	// Manifest should be moved to manifest/ dir.
	case oldName == "AndroidManifest.xml":
		return "manifest/AndroidManifest.xml"
	// Dex files need to be moved under dex/ dir.
	case strings.HasSuffix(oldName, ".dex"):
		return "dex/" + oldName
	// All other files (probably JVM metadata files) should be moved to root/ dir.
	default:
		return "root/" + oldName
	}
}
