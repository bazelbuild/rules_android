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

// Package compile is a thin wrapper around aapt2 to compile android resources.
package compile

import (
	"flag"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	"src/common/golang/ziputils"
	"src/tools/ak/types"
)

var (
	// Cmd defines the command to run compile
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"aapt2",
			"in",
			"out",
		},
	}

	in    string
	aapt2 string
	out   string

	initOnce sync.Once

	dirPerm       os.FileMode = 0755
	dirReplacer               = strings.NewReplacer("sr-rLatn", "b+sr+Latn", "es-419", "b+es+419")
	archiveSuffix             = ".zip"
)

// Init initializes compile.
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&aapt2, "aapt2", "", "Path to the aapt2 binary.")
		flag.StringVar(&in, "in", "", "Input res bucket/dir to compile.")
		flag.StringVar(&out, "out", "", "The compiled resource archive.")
	})
}

func desc() string {
	return "Compile android resources directory."
}

// Run is the entry point for compile.
func Run() {
	if in == "" || aapt2 == "" || out == "" {
		log.Fatal("Flags -in and -aapt2 and -out must be specified.")
	}

	fi, err := os.Stat(in)
	if err != nil {
		log.Fatal(err)
	}

	resDir := in
	if !fi.IsDir() {
		if strings.HasSuffix(resDir, archiveSuffix) {
			// We are dealing with a resource archive.
			td, err := ioutil.TempDir("", "-res")
			if err != nil {
				log.Fatal(err)
			}

			resDir = filepath.Join(td, "res/")
			if err := os.MkdirAll(resDir, dirPerm); err != nil {
				log.Fatal(err)
			}
			if err := ziputils.Unzip(in, td); err != nil {
				log.Fatal(err)
			}
		} else {
			// We are compiling a single file, but we need to provide dir.
			resDir = filepath.Dir(filepath.Dir(resDir))
		}
	}

	if err := sanitizeDirs(resDir, dirReplacer); err != nil {
		log.Fatal(err)
	}

	cmd := exec.Command(aapt2, []string{"compile", "--legacy", "-o", out, "--dir", resDir}...)
	if out, err := cmd.CombinedOutput(); err != nil {
		log.Fatalf("error compiling resources for resource directory %s: %v\n%s", resDir, err, string(out))
	}
}

// sanitizeDirs renames the directories that aapt is unable to parse
func sanitizeDirs(dir string, r *strings.Replacer) error {
	src, err := os.Open(dir)
	if err != nil {
		return err
	}
	defer src.Close()

	fs, err := src.Readdir(-1)
	if err != nil {
		return err
	}

	for _, f := range fs {
		if f.Mode().IsDir() {
			if qd := r.Replace(f.Name()); qd != f.Name() {
				if err := os.Rename(filepath.Join(dir, f.Name()), filepath.Join(dir, qd)); err != nil {
					return err
				}
			}
		}
	}
	return nil
}
