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

// Package shellapk creates a minimal shell apk.
package shellapk

import (
	"archive/zip"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"src/common/golang/fileutils"
	"src/common/golang/flags"
	"src/common/golang/ziputils"
	"src/tools/ak/types"
)

const (
	swigdepsFileName    = "nativedeps.txt"
	jarManifestFileName = "META-INF/MANIFEST.MF"

	// see https://docs.oracle.com/javase/tutorial/deployment/jar/defman.html
	defJarManifestContents = "Manifest-Version: 1.0\nCreated-By: ak"
)

var (
	// Cmd defines the command to run shellapk.
	Cmd = types.Command{
		Init:  Init,
		Run:   Run,
		Desc:  desc,
		Flags: []string{"java_resources", "dummy_native_libs", "jdk", "dex_file", "manifest_package_name", "in_application_class_name", "shell_app", "android_manifest", "arsc_path", "android_resources_zip", "linked_native_library"},
	}

	// Variables to hold flag values.
	javaRes         flags.StringList
	dummyNativeLibs string
	jdk             string
	dexFile         string
	manifestPkgName string
	inAppClassName  string
	out             string
	manifest        string
	arsc            string
	resZip          string
	linkedNativeLib string

	initOnce sync.Once
)

// Init initializes shellapk.
func Init() {
	initOnce.Do(func() {
		flag.Var(&javaRes, "java_resources", "Path to java resource file.")
		flag.StringVar(&dummyNativeLibs, "dummy_native_libs", "", "Native libraries files.")
		flag.StringVar(&jdk, "jdk", "", "JDK path.")
		flag.StringVar(&dexFile, "dex_file", "", "Dex file with stubby classes for apk.")
		flag.StringVar(&manifestPkgName, "manifest_package_name", "", "Manifest package name.")
		flag.StringVar(&inAppClassName, "in_application_class_name", "", "Path for the application class name.")
		flag.StringVar(&out, "shell_app", "", "Output path for the shell apk.")
		flag.StringVar(&manifest, "android_manifest", "", "Binary AndroidManifest.xml artifact.")
		flag.StringVar(&arsc, "arsc_path", "", "Path to the arsc table.")
		flag.StringVar(&resZip, "android_resources_zip", "", "Android resources files.")
		flag.StringVar(&linkedNativeLib, "linked_native_library", "", "Linked native lib name that needs to be outputed on the swigdeps file.")
	})
}

func desc() string {
	return "Shellapk creates a minimal shell apk."
}

// Run is the entry point for shellapk.
func Run() {
	if err := doWork(
		out,
		javaRes,
		dummyNativeLibs,
		jdk,
		dexFile,
		manifestPkgName,
		inAppClassName,
		manifest,
		arsc,
		resZip,
		linkedNativeLib); err != nil {
		log.Fatalf("Error creating shellapk: %v", err)
	}
}

func doWork(out string, javaRes []string, dummyNativeLibs, jdk, dexFile, manifestPkgName, inAppClassName, manifest, arsc, resZip, linkedNativeLib string) error {
	// Create temp dir for all apk files
	apkDir, err := ioutil.TempDir("", "shellapk")
	if err != nil {
		return err
	}
	defer os.RemoveAll(apkDir)

	// Exctract dexes
	if err := extractDexes(apkDir, dexFile); err != nil {
		return err
	}

	// Extract java resources
	for _, f := range javaRes {
		if err := ziputils.Unzip(f, apkDir); err != nil {
			return err
		}
	}

	// Copy manifest
	if err := fileutils.Copy(manifest, filepath.Join(apkDir, "AndroidManifest.xml")); err != nil {
		return err
	}

	// Write output zip
	w, err := os.Create(out)
	if err != nil {
		return err
	}
	defer w.Close()
	zipOut := zip.NewWriter(w)
	defer zipOut.Close()

	// Write all files in apkDir
	err = filepath.Walk(apkDir, func(path string, f os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if !f.IsDir() {
			// Filter out META-INF/MANIFEST.MF. If this file is not correct
			// the apk signer will refuse to touch the apk.
			if path[len(apkDir)+1:] == jarManifestFileName {
				return nil
			}

			n := strings.TrimLeft(strings.TrimPrefix(path, apkDir), "/")
			if err := ziputils.WriteFile(zipOut, path, n); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return err
	}

	// Copy all files from android resources zip
	r, err := zip.OpenReader(resZip)
	if err != nil {
		return err
	}
	for _, f := range r.File {
		if strings.HasSuffix(f.Name, "AndroidManifest.xml") {
			continue
		}
		fR, err := f.Open()
		if err != nil {
			return err
		}
		if err := ziputils.WriteReader(zipOut, fR, f.Name); err != nil {
			return err
		}
	}
	r.Close()

	// Copy all native files from dummy native libs
	if dummyNativeLibs != "" {
		r, err := zip.OpenReader(dummyNativeLibs)
		if err != nil {
			return err
		}
		for _, f := range r.File {
			if !strings.HasSuffix(f.Name, ".so") {
				continue
			}
			fR, err := f.Open()
			if err != nil {
				return err
			}
			ziputils.WriteReader(zipOut, fR, f.Name)
		}
		r.Close()
	}

	if err := ziputils.WriteReader(zipOut, strings.NewReader(defJarManifestContents), jarManifestFileName); err != nil {
		return err
	}

	if err := ziputils.WriteFile(zipOut, manifestPkgName, "package_name.txt"); err != nil {
		return err
	}
	if err := ziputils.WriteFile(zipOut, inAppClassName, "app_name.txt"); err != nil {
		return err
	}
	if linkedNativeLib != "" {
		if err = ziputils.WriteFile(zipOut, linkedNativeLib, swigdepsFileName); err != nil {
			return err
		}
	}
	if arsc != "" {
		if err = ziputils.WriteFile(zipOut, arsc, "resources.arsc"); err != nil {
			return err
		}
	}

	return nil
}

func extractDexes(dir, zipFile string) error {
	r, err := zip.OpenReader(zipFile)
	if err != nil {
		return err
	}
	defer r.Close()

	dexOut, err := os.Create(filepath.Join(dir, "classes.dex"))
	if err != nil {
		return err
	}
	defer dexOut.Close()
	dexCount := 0
	for _, f := range r.File {
		if strings.HasSuffix(f.Name, ".dex") {
			dexCount++
			dR, err := f.Open()
			if err != nil {
				return err
			}
			io.Copy(dexOut, dR)
		}
	}
	if dexCount != 1 {
		return fmt.Errorf("expected 1 dex in %s, actually %d", dexFile, dexCount)
	}
	return nil
}
