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

// Package nativelib creates the native library zip.
package nativelib

import (
	"archive/zip"
	"bufio"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"

	"src/common/golang/fileutils"
	"src/common/golang/flags"
	"src/common/golang/ziputils"
	"src/tools/ak/types"
)

var (
	// Cmd defines the command to run nativelib.
	Cmd = types.Command{
		Init:  Init,
		Run:   Run,
		Desc:  desc,
		Flags: []string{"lib", "native_libs_zip", "out"},
	}

	// Variables to hold flag values
	nativeLibs    flags.StringList
	nativeLibsZip flags.StringList
	out           string

	initOnce sync.Once
)

// Init initializes nativelib.
func Init() {
	initOnce.Do(func() {
		flag.Var(&nativeLibs, "lib", "Path to native lib.")
		flag.Var(&nativeLibsZip, "native_libs_zip", "Zip(s) containing native libs.")
		flag.StringVar(&out, "out", "", "Native libraries files.")
	})
}

func desc() string {
	return "Nativelib creates the native lib zip."
}

// Run is the entry point for nativelib.
func Run() {
	if nativeLibsZip != nil {
		dstDir, err := ioutil.TempDir("", "ziplibs")
		if err != nil {
			log.Fatalf("Error creating native lib zip: %v", err)
		}

		for _, native := range nativeLibsZip {
			libs, err := extractLibs(native, dstDir)
			if err != nil {
				log.Fatalf("Error creating native lib zip: %v", err)
			}
			nativeLibs = append(nativeLibs, libs...)
		}
	}

	if err := doWork(nativeLibs, out); err != nil {
		log.Fatalf("Error creating native lib zip: %v", err)
	}
}

func extractLibs(libZip, dstDir string) ([]string, error) {
	zr, err := zip.OpenReader(libZip)
	if err != nil {
		return nil, err
	}
	defer zr.Close()

	libs := []string{}
	for _, f := range zr.File {
		if f.Mode().IsDir() {
			continue
		}
		arch := filepath.Base(filepath.Dir(f.Name))
		libs = append(libs, fmt.Sprintf("%s:%s", arch, filepath.Join(dstDir, f.Name)))
	}
	if err := ziputils.Unzip(libZip, dstDir); err != nil {
		return nil, err
	}
	return libs, nil
}

func doWork(nativeLibs []string, out string) error {
	nativeDir, err := ioutil.TempDir("", "nativelib")
	if err != nil {
		return err
	}
	defer os.RemoveAll(nativeDir)
	nativePaths, err := copyNativeLibs(nativeLibs, nativeDir)
	if err != nil {
		return err
	}
	zipFile, err := os.Create(out)
	if err != nil {
		return err
	}
	writer := bufio.NewWriter(zipFile)
	zipWriter := zip.NewWriter(writer)
	sort.Strings(nativePaths)
	for _, f := range nativePaths {
		p, err := filepath.Rel(nativeDir, f)
		if err != nil {
			return err
		}
		ziputils.WriteFile(zipWriter, f, p)
	}
	zipWriter.Close()
	return nil
}

func copyNativeLibs(nativeLibs []string, dir string) ([]string, error) {
	var paths []string
	for _, cpuNativeLib := range nativeLibs {
		r := strings.SplitN(cpuNativeLib, ":", 2)
		if len(r) != 2 {
			return nil, errors.New("error parsing native lib")
		}
		arch := r[0]
		nativeLib := r[1]
		if arch == "armv7a" {
			arch = "armeabi-v7a"
		}
		libOutDir := filepath.Join(dir, "lib", arch)
		if err := os.MkdirAll(libOutDir, 0777); err != nil && !os.IsExist(err) {
			return nil, err
		}
		outNativeLibPath := filepath.Join(libOutDir, filepath.Base(nativeLib))
		if err := fileutils.Copy(nativeLib, outNativeLibPath); err != nil {
			return nil, err
		}
		paths = append(paths, outNativeLibPath)
	}
	return paths, nil
}
