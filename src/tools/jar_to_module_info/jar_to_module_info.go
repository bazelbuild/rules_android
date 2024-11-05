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

// Creates a module-info.java that exports all packages in the provided .jar file; see README.md
package main

import (
	"archive/zip"
	"bytes"
	"context"
	"fmt"
	"strings"

	"bitbucket.org/creachadair/stringset"
	"flag"
	"log"
	"os"
)

var (
	inputPath  = flag.String("input", "", "input jar path")
	outputPath = flag.String("output", "", "output modile-info path")
)

func writeFilePortable(ctx context.Context, filename string, data []byte) error {
	// A portable shim around the google-internal WriteFile() and the more commonly-used public version.
	// The Google-internal WriteFile() takes an additional Context object.
	return os.WriteFile(filename, data, 0o400)
}

func portableInit() {
	flag.Parse()
}

func main() {
	portableInit()
	reader, err := zip.OpenReader(*inputPath)
	if err != nil {
		log.Fatal(err)
	}
	defer reader.Close()
	packages := stringset.New()
	for _, f := range reader.File {
		if !strings.HasSuffix(f.Name, ".class") {
			continue
		}
		idx := strings.LastIndex(f.Name, "/")
		if idx == -1 {
			continue
		}
		packages.Add(f.Name[:idx])
	}
	var output bytes.Buffer
	fmt.Fprintln(&output, "module java.base {")
	for _, p := range packages.Elements() {
		fmt.Fprintf(&output, "  exports %s;\n", strings.Replace(p, "/", ".", -1))
	}
	fmt.Fprintln(&output, "}")
	err = writeFilePortable(context.Background(), *outputPath, output.Bytes())
	if err != nil {
		log.Fatal(err)
	}
}
