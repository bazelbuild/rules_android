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

// Package link is a thin wrapper around aapt2 to link android resources.
package link

import (
	"flag"
	"io/ioutil"
	"log"
	"os/exec"
	"sync"

	"src/common/golang/flags"
	"src/common/golang/walk"
	"src/common/golang/ziputils"
	"src/tools/ak/types"
)

var (
	// Cmd defines the command to run link.
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"aapt2",
			"sdk_jar",
			"manifest",
			"res_dirs",
			"asset_dirs",
			"pkg",
			"src_jar",
			"out",
		},
	}

	aapt2     string
	sdkJar    string
	manifest  string
	resDirs   flags.StringList
	assetDirs flags.StringList
	pkg       string
	srcJar    string
	out       string

	initOnce sync.Once
)

// Init initializes link.
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&aapt2, "aapt2", "", "Path to the aapt2 binary.")
		flag.StringVar(&sdkJar, "sdk_jar", "", "Path to the android jar.")
		flag.StringVar(&manifest, "manifest", "", "Path to the application AndroidManifest.xml.")
		flag.Var(&resDirs, "res_dirs", "List of resource archives to link.")
		flag.Var(&assetDirs, "asset_dirs", "Paths to asset directories..")
		flag.StringVar(&pkg, "pkg", "", "Package for R.java.")
		flag.StringVar(&srcJar, "src_jar", "", "R java source jar path.")
		flag.StringVar(&out, "out", "", "Output path for linked archive.")
	})
}

func desc() string {
	return "Link compiled Android resources."
}

// Run is the entry point for link.
func Run() {
	if aapt2 == "" ||
		sdkJar == "" ||
		manifest == "" ||
		resDirs == nil ||
		pkg == "" ||
		srcJar == "" ||
		out == "" {
		log.Fatal("Flags -aapt2 -sdk_jar -manifest -res_dirs -pkg -src_jar and -out must be specified.")
	}

	// Note that relative order between directories needs to be respected by traversal function.
	// I.e. all files in dir n most come before all files in directory n+1.
	resArchives, err := walk.Files(resDirs)
	if err != nil {
		log.Fatalf("error getting resource archives: %v", err)
	}

	rjavaDir, err := ioutil.TempDir("", "rjava")
	if err != nil {
		log.Fatalf("error creating temp dir: %v", err)
	}

	args := []string{
		"link", "--manifest", manifest, "--auto-add-overlay", "--no-static-lib-packages",
		"--java", rjavaDir, "--custom-package", pkg, "-I", sdkJar}

	for _, r := range resArchives {
		args = append(args, "-R", r)
	}

	for _, a := range assetDirs {
		args = append(args, "-A", a)
	}

	args = append(args, "-o", out)

	if out, err := exec.Command(aapt2, args...).CombinedOutput(); err != nil {
		log.Fatalf("error linking Android resources: %v\n %s", err, string(out))
	}
	if err := ziputils.Zip(rjavaDir, srcJar); err != nil {
		log.Fatalf("error unable to create resources src jar: %v", err)
	}
}
