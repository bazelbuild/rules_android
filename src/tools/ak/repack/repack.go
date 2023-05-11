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

// Package repack provides functionality to repack zip/jar/apk archives.
package repack

import (
	"archive/zip"
	"flag"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"src/common/golang/flags"
	"src/tools/ak/types"
)

var (
	// Cmd defines the command to run repack
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"in",
			"dir",
			"out",
			"filtered_out",
			"filter_r",
			"filter_jar_res",
			"filter_manifest",
			"compress",
			"remove_dirs",
		},
	}

	// Variables that hold flag values
	in             flags.StringList
	dir            flags.StringList
	out            string
	filteredOut    string
	filterR        bool
	filterJarRes   bool
	filterManifest bool
	compress       bool
	removeDirs     bool

	b2i      = map[bool]int8{false: 0, true: 1}
	seen     = make(map[string]bool)
	initOnce sync.Once
)

// Init initializes repack.
func Init() {
	initOnce.Do(func() {
		flag.Var(&in, "in", "Path to input(s), must be a zip archive.")
		flag.Var(&dir, "dir", "Path to directories to pack in the zip.")
		flag.StringVar(&out, "out", "", "Path to output.")
		flag.StringVar(&filteredOut, "filtered_out", "", "(optional) Path to output for filtered files.")
		flag.BoolVar(&filterR, "filter_r", false, "Whether to filter R classes or not.")
		flag.BoolVar(&filterJarRes, "filter_jar_res", false, "Whether to filter java resources or not.")
		flag.BoolVar(&filterManifest, "filter_manifest", false, "Whether to filter AndroidManifest.xml or not.")
		flag.BoolVar(&compress, "compress", false, "Whether to compress or just store files in all outputs.")
		flag.BoolVar(&removeDirs, "remove_dirs", true, "Whether to remove directory entries or not.")
	})
}

func desc() string {
	return "Repack zip/jar/apk archives."
}

type filterFunc func(name string) bool

func filterNone(name string) bool {
	return false
}

func isRClass(name string) bool {
	return strings.HasSuffix(name, "/R.class") || strings.Contains(name, "/R$")
}

func isJavaRes(name string) bool {
	return !(strings.HasSuffix(name, ".class") || strings.HasPrefix(name, "META-INF/"))
}

func isManifest(name string) bool {
	return name == "AndroidManifest.xml"
}

func repackZip(in *zip.Reader, out *zip.Writer, filteredZipOut *zip.Writer, filter filterFunc, method uint16) error {
	for _, f := range in.File {
		if removeDirs && strings.HasSuffix(f.Name, "/") {
			continue
		}
		reader, err := f.Open()
		if err != nil {
			return err
		}
		if err := writeToZip(f.Name, reader, out, filteredZipOut, filter, method); err != nil {
			return err
		}
		if err := reader.Close(); err != nil {
			return err
		}
	}
	return nil
}

func repackDir(dir string, out *zip.Writer, filteredZipOut *zip.Writer, filter filterFunc, method uint16) error {
	return filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		name, err := filepath.Rel(dir, path)
		if info.IsDir() {
			if removeDirs {
				return nil
			}
			name += "/"
		}

		reader, err := os.Open(path)
		if err != nil {
			return err
		}
		defer reader.Close()

		return writeToZip(name, reader, out, filteredZipOut, filter, method)
	})
}

func writeToZip(name string, in io.Reader, out, filteredZipOut *zip.Writer, filter filterFunc, method uint16) error {
	if seen[name] {
		return nil
	}
	seen[name] = true

	if filter(name) {
		if filteredZipOut != nil {
			write(filteredZipOut, in, name, method)
		}
		return nil
	}
	return write(out, in, name, method)
}

func write(out *zip.Writer, in io.Reader, name string, method uint16) error {
	writer, err := out.CreateHeader(&zip.FileHeader{
		Name:   name,
		Method: method,
	})
	if err != nil {
		return err
	}

	// Only files have data, io.Copy will fail for directories. Header entry is required for both.
	if !strings.HasSuffix(name, "/") {
		if _, err := io.Copy(writer, in); err != nil {
			return err
		}
	}
	return nil
}

// Run is the entry point for repack.
func Run() {
	if in == nil && dir == nil {
		log.Fatal("Flags -in or -dir must be specified.")
	}
	if out == "" {
		log.Fatal("Flags -out must be specified.")
	}

	if b2i[filterR]+b2i[filterJarRes]+b2i[filterManifest] > 1 {
		log.Fatal("Only one filter is allowed.")
	}

	filter := filterNone
	if filterR {
		filter = isRClass
	} else if filterJarRes {
		filter = isJavaRes
	} else if filterManifest {
		filter = isManifest
	}

	w, err := os.Create(out)
	if err != nil {
		log.Fatalf("os.Create(%q) failed: %v", out, err)
	}
	defer w.Close()

	zipOut := zip.NewWriter(w)
	defer zipOut.Close()

	var filteredZipOut *zip.Writer
	if filteredOut != "" {
		w, err := os.Create(filteredOut)
		if err != nil {
			log.Fatalf("os.Create(%q) failed: %v", filteredOut, err)
		}
		defer w.Close()
		filteredZipOut = zip.NewWriter(w)
		defer filteredZipOut.Close()
	}

	method := zip.Store
	if compress {
		method = zip.Deflate
	}

	for _, d := range dir {
		if err := repackDir(d, zipOut, filteredZipOut, filter, method); err != nil {
			log.Fatal(err)
		}
	}

	for _, f := range in {
		file, err := os.Open(f)
		if err != nil {
			log.Fatalf("os.Open(%q) failed: %v", f, err)
		}
		fi, err := file.Stat()
		if err != nil {
			file.Close()
			log.Fatalf("File.Stat() failed for %q: %v", f, err)
		}
		size := fi.Size()
		// Skip empty Zip archives. An empty zip is 22 bytes contains only an EOCD.
		// https://en.wikipedia.org/wiki/Zip_(file_format)#Limits
		if size <= 22 {
			continue
		}
		zipIn, err := zip.NewReader(file, size)
		if err != nil {
			file.Close()
			log.Fatalf("zip.OpenReader(%q) failed: %v", f, err)
		}

		err = repackZip(zipIn, zipOut, filteredZipOut, filter, method)
		file.Close()
		if err != nil {
			log.Fatal(err)
		}
	}
}
