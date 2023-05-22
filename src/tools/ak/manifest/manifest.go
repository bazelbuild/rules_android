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

// Package manifest provides a thin wrapper around aapt2 to compile an AndroidManifest.xml
package manifest

import (
	"archive/zip"
	"bytes"
	"flag"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sync"

	"src/common/golang/flags"
	"src/tools/ak/manifestutils"
	"src/tools/ak/types"
)

const errMsg string = `
+-----------------------------------------------------------
| Error while compiling AndroidManifest.xml
| If your build succeeds with Blaze/Bazel build, this is most
| likely due to the stricter aapt2 used by mobile-install
` +
	`
+-----------------------------------------------------------
ERROR: %s
`

var (
	// Cmd defines the command to run
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"aapt2",
			"manifest",
			"out",
			"sdk_jar",
			"res",
			"attr",
		},
	}

	// Flag variables
	aapt2, manifest, out, sdkJar, res string
	attr                              flags.StringList
	forceDebuggable                   bool

	initOnce sync.Once
)

// Init initializes manifest flags
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&aapt2, "aapt2", "", "Path to aapt2")
		flag.StringVar(&manifest, "manifest", "", "Path to manifest")
		flag.StringVar(&out, "out", "", "Path to output")
		flag.StringVar(&sdkJar, "sdk_jar", "", "Path to sdk jar")
		flag.StringVar(&res, "res", "", "Path to res")
		flag.BoolVar(&forceDebuggable, "force_debuggable", false, "Whether to force set android:debuggable=true.")
		flag.Var(&attr, "attr", "(optional) attr(s) to set. {element}:{attr}:{value}.")
	})
}

func desc() string {
	return "Compile an AndroidManifest.xml"
}

// Run is the main entry point
func Run() {
	if aapt2 == "" || manifest == "" || out == "" || sdkJar == "" || res == "" {
		log.Fatal("Missing required flags. Must specify --aapt2 --manifest --out --sdk_jar --res")
	}

	aaptOut, err := ioutil.TempFile("", "manifest_apk")
	if err != nil {
		log.Fatalf("Creating temp file failed: %v", err)
	}
	defer os.Remove(aaptOut.Name())

	manifestPath := manifest
	if len(attr) > 0 {
		patchedManifest, err := ioutil.TempFile("", "AndroidManifest_patched.xml")
		if err != nil {
			log.Fatalf("Creating temp file failed: %v", err)
		}
		defer os.Remove(patchedManifest.Name())
		manifestPath = patchManifest(manifest, patchedManifest, attr)
	}
	args := []string{"link", "-o", aaptOut.Name(), "--manifest", manifestPath, "-I", sdkJar, "-I", res}
	if forceDebuggable {
		args = append(args, "--debug-mode")
	}
	stdoutStderr, err := exec.Command(aapt2, args...).CombinedOutput()
	if err != nil {
		log.Fatalf(errMsg, stdoutStderr)
	}

	reader, err := zip.OpenReader(aaptOut.Name())
	if err != nil {
		log.Fatalf("Opening zip %q failed: %v", aaptOut.Name(), err)
	}
	defer reader.Close()

	for _, file := range reader.File {
		if file.Name == "AndroidManifest.xml" {
			err = os.MkdirAll(filepath.Dir(out), os.ModePerm)
			if err != nil {
				log.Fatalf("Creating output directory for %q failed: %v", out, err)
			}

			fileReader, err := file.Open()
			if err != nil {
				log.Fatalf("Opening file %q inside zip %q failed: %v", file.Name, aaptOut.Name(), err)
			}
			defer fileReader.Close()

			outFile, err := os.Create(out)
			if err != nil {
				log.Fatalf("Creating output %q failed: %v", out, err)
			}

			if _, err := io.Copy(outFile, fileReader); err != nil {
				log.Fatalf("Writing to output %q failed: %v", out, err)
			}

			if err = outFile.Close(); err != nil {
				log.Fatal(err)
			}
			break
		}
	}
}

func patchManifest(manifest string, patchedManifest *os.File, attrs []string) string {
	b, err := ioutil.ReadFile(manifest)
	if err != nil {
		log.Fatalf("Failed to read manifest: %v", err)
	}
	err = manifestutils.WriteManifest(patchedManifest, bytes.NewReader(b), manifestutils.CreatePatchElements(attrs))
	if err != nil {
		log.Fatalf("Failed to update manifest: %v", err)
	}
	return patchedManifest.Name()
}
