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

// Package dex provides a thin wrapper around d8 to handle corner cases
package dex

import (
	"archive/zip"
	"bufio"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"

	"src/common/golang/flags"
	"src/common/golang/shard"
	"src/common/golang/ziputils"
	"src/tools/ak/types"
)

var (
	// Cmd defines the command to run
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"desugar",
			"android_jar",
			"desugar_core_libs",
			"desugared_lib_config",
			"classpath",
			"dexbuilder",
			"in",
			"out",
			"min_sdk_version",
		},
	}

	tmp struct {
		Dir string
	}

	// Flag variables
	desugar, androidJar, dexbuilder, in string
	classpaths, outs, outputDir         flags.StringList
	desugarCoreLibs                     bool
	desugaredLibConfig                  string
	minSdkVersion                       int

	initOnce sync.Once
)

// Init initializes manifest flags
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&desugar, "desugar", "", "Path to desugar tool")
		flag.StringVar(&androidJar, "android_jar", "", "Required for desugar, path to android.jar")
		flag.Var(&classpaths, "classpath", "(Optional) Path to library resource(s) for desugar")
		flag.BoolVar(&desugarCoreLibs, "desugar_core_libs", false, "Desugar Java 8 core libs, default false")
		flag.StringVar(&desugaredLibConfig, "desugared_lib_config", "", "Path to desugared lib config")
		flag.StringVar(&dexbuilder, "dexbuilder", "", "Path to dexbuilder")
		flag.StringVar(&in, "in", "", "Path to input")
		flag.Var(&outs, "out", "Path to output, if more than one specified, output is sharded across files.")
		flag.IntVar(&minSdkVersion, "min_sdk_version", 0, "Passthrough to d8 for desugaring and dexing.")
	})
}

func desc() string {
	return "Dex converts Java byte code to Dex code."
}

// Run is the main entry point
func Run() {
	if desugar != "" && androidJar == "" {
		log.Fatal("--android_jar is required for desugaring")
	}
	if dexbuilder == "" || in == "" || outs == nil {
		log.Fatal("Missing required flags. Must specify --dexbuilder --in --out")
	}
	sc := len(outs)
	if sc > 256 {
		log.Fatalf("%d: is an unreasonable shard count (want [1 to 256])", sc)
	}

	var err error
	tmp.Dir, err = ioutil.TempDir("", "dex")
	if err != nil {
		log.Fatalf("Error creating temp dir: %v", err)
	}
	defer os.RemoveAll(tmp.Dir)

	notEmpty, err := hasCode(in)
	if err != nil {
		log.Fatal(err)
	}

	if notEmpty {
		jar := in
		if desugar != "" {
			jar = filepath.Join(tmp.Dir, "desugared.jar")
			if err = desugarJar(in, jar); err != nil {
				log.Fatalf("Error desugaring %v: %v", in, err)
			}
		}
		if sc == 1 {
			if err = dexBuilder(jar, outs[0]); err != nil {
				log.Fatalf("Dex error: %v", err)
			}
		} else {
			out := filepath.Join(tmp.Dir, "dexed.zip")
			if err = dexBuilder(jar, out); err != nil {
				log.Fatalf("Dex error: %v", err)
			}
			if err = zipShard(out, outs); err != nil {
				log.Fatalf("ZipShard error: %v", err)
			}
		}
	} else {
		for _, out := range outs {
			if err := ziputils.EmptyZip(out); err != nil {
				log.Fatalf("Error creating empty zip archive: %v", err)
			}
		}
	}
}

func createFlagFile(args []string) (string, error) {
	f, err := ioutil.TempFile(tmp.Dir, "flags")
	if err != nil {
		return "", err
	}
	for _, arg := range args {
		if _, err := f.WriteString(arg + "\n"); err != nil {
			return "", err
		}
	}
	if err := f.Close(); err != nil {
		return "", err
	}
	return f.Name(), nil
}

func hasCode(f string) (bool, error) {
	reader, err := zip.OpenReader(f)
	if err != nil {
		return false, fmt.Errorf("Opening zip %q failed: %v", f, err)
	}
	defer reader.Close()

	for _, file := range reader.File {
		ext := filepath.Ext(file.Name)
		if ext == ".class" || ext == ".dex" {
			return true, nil
		}
	}
	return false, nil
}

func desugarJar(in, out string) error {
	args := []string{
		"--input",
		in,
		"--bootclasspath_entry",
		androidJar,
		"--output",
		out,
	}
	if minSdkVersion > 0 {
		args = append(args, "--min_sdk_version", strconv.Itoa(minSdkVersion))
	}
	if desugarCoreLibs {
		args = append(args, "--desugar_supported_core_libs")
	}
	if desugaredLibConfig != "" {
		args = append(args, "--desugared_lib_config", desugaredLibConfig)
	} else {
		log.Fatalf("Expected --desugared_lib_config <path>.")
	}
	for _, cp := range classpaths {
		args = append(args, "--classpath_entry", cp)
	}
	return runCmd(desugar, args)
}

func dexBuilder(in, out string) error {
	args := []string{
		"--input_jar",
		in,
		"--output_zip",
		out,
	}
	if minSdkVersion > 0 {
		args = append(args, "--min_sdk_version", strconv.Itoa(minSdkVersion))
	}
	return runCmd(dexbuilder, args)
}

func runCmd(cmd string, args []string) error {
	flagFile, err := createFlagFile(args)
	if err != nil {
		return fmt.Errorf("Error creating flag file: %v", err)
	}
	output, err := exec.Command(cmd, "@"+flagFile).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%v:\n%s", err, output)
	}
	return nil
}

func zipShard(input string, outs []string) error {
	zr, err := zip.OpenReader(input)
	if err != nil {
		return fmt.Errorf("%s: cannot open for input: %v", input, err)
	}
	defer zr.Close()

	if len(outs) < 2 {
		log.Fatalf("Need at least two output shards)")
	}

	zws := make([]*zip.Writer, len(outs))
	for i, out := range outs {
		outDir := filepath.Dir(out)
		if _, err := os.Stat(outDir); os.IsNotExist(err) {
			if err := os.MkdirAll(outDir, 0755); err != nil {
				return fmt.Errorf("%s: could not make dir: %v", input, outDir)
			}
		}
		outF, err := os.Create(out)
		if err != nil {
			return fmt.Errorf("%s: could not create output file: %s %v", out, outDir, err)
		}
		w := bufio.NewWriterSize(outF, 2<<16)
		zw := zip.NewWriter(w)
		defer func() error {
			if err := zw.Close(); err != nil {
				return fmt.Errorf("%s: closing zip failed: %v", out, err)
			}
			if err := w.Flush(); err != nil {
				return fmt.Errorf("%s: flushing output file failed: %v", out, err)
			}
			if err := outF.Close(); err != nil {
				return fmt.Errorf("%s: closing output file failed: %v", out, err)
			}
			return nil
		}()
		zws[i] = zw
	}

	err = shard.ZipShard(&zr.Reader, zws, shardFn)
	if err != nil {
		return fmt.Errorf("%s: sharder failed: %v", input, err)
	}
	return nil
}

func shardFn(name string, shardCount int) int {
	// Sharding function which ensures that a class and all its inner classes are
	// placed in the same shard. An important side effect of this is that all D8
	// synthetics are in the same shard as their context, as a synthetic is named
	// <context>$$ExternalSyntheticXXXN.
	index := len(name)
	if strings.HasSuffix(name, ".class.dex") {
		// DexBuilder creates archives with .class.dex files
		index -= 10
	} else if strings.HasSuffix(name, ".dex") {
		// D8 creates archives with .dex files
		index -= 4
	} else {
		log.Fatalf("Name expected to end with '.dex' or '.class.dex', was: %s", name)
	}
	trimIndex := strings.IndexAny(name, "$-")
	if trimIndex > -1 {
		index = trimIndex
	}
	return shard.FNV(name[:index], shardCount)
}
