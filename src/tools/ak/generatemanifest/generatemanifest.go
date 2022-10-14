// Copyright 2022 The Bazel Authors. All rights reserved.
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

// Package generatemanifest is a command line tool to generate an empty AndroidManifest
package generatemanifest

import (
	"bufio"
	"encoding/xml"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"sync"

	"src/common/golang/flags"
	"src/tools/ak/types"
)

// Structs used for reading the manifest xml file
type manifestTag struct {
	XMLName xml.Name   `xml:"manifest"`
	UsesSdk usesSdkTag `xml:"uses-sdk"`
}

type usesSdkTag struct {
	XMLName xml.Name `xml:"uses-sdk"`
	MinSdk  string   `xml:"minSdkVersion,attr"`
}

type result struct {
	minSdk int
	err    error
}

const manifestContent string = `<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="%s">
    <uses-sdk android:minSdkVersion="%d" />
    <application/>
</manifest>
`

var (
	// Cmd defines the command to run
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"out",
			"java_package",
			"manifests",
			"minsdk",
		},
	}

	// Flag variables
	out, javaPackage string
	minSdk           int
	manifests        flags.StringList

	initOnce sync.Once
)

// Init initializes manifest flags
func Init() {
	initOnce.Do(func() {
		flag.StringVar(&out, "out", "", "Path to output manifest generated with the max min sdk value found from --manifests.")
		flag.StringVar(&javaPackage, "java_package", "com.default", "(optional) Java package to use for the manifest.")
		flag.IntVar(&minSdk, "minsdk", 14, "(optional) Default min sdk to support.")
		flag.Var(&manifests, "manifests", "(optional) Manifests(s) to get min sdk from.")
	})
}

func desc() string {
	return "Generates an empty AndroidManifest.xml with a minSdk value. The min sdk is selected " +
		"by taking the max value found between the manifests and the minsdk flag."
}

// Run is the main entry point
func Run() {
	if out == "" {
		log.Fatal("Missing required flag. Must specify --out")
	}

	var manifestFiles []io.ReadCloser
	for _, manifest := range manifests {
		manifestFile, err := os.Open(manifest)
		if err != nil {
			log.Fatalf("error opening manifest %s: %v", manifest, err)
		}
		manifestFiles = append(manifestFiles, manifestFile)
	}
	defer func(manifestFiles []io.ReadCloser) {
		for _, manifestFile := range manifestFiles {
			manifestFile.Close()
		}
	}(manifestFiles)

	extractedMinSdk, err := extractMinSdk(manifestFiles, minSdk)
	if err != nil {
		log.Fatalf("error extracting min sdk from manifests: %v", err)
	}

	outFile, err := os.Create(out)
	if err != nil {
		log.Fatalf("error opening output manifest: %v", err)
	}
	defer outFile.Close()
	if err := writeManifest(outFile, javaPackage, extractedMinSdk); err != nil {
		log.Fatalf("error writing output manifest: %v", err)
	}
}

// The min sdk is selected by taking the max value found
// between the manifests and the minsdk flag
func extractMinSdk(manifests []io.ReadCloser, defaultSdk int) (int, error) {
	// Extracting minSdk values in goroutines
	results := make(chan result, len(manifests))
	var wg sync.WaitGroup
	wg.Add(len(manifests))
	for _, manifestFile := range manifests {
		go func(manifestFile io.Reader) {
			res := extractMinSdkFromManifest(manifestFile)
			results <- res
			wg.Done()
		}(manifestFile)
	}
	wg.Wait()
	close(results)

	// Finding max value from channel
	minSdk := defaultSdk
	for result := range results {
		if result.err != nil {
			return 0, result.err
		}
		minSdk = max(minSdk, result.minSdk)
	}
	return minSdk, nil
}

func extractMinSdkFromManifest(reader io.Reader) result {
	manifestBytes, err := ioutil.ReadAll(reader)
	if err != nil {
		return result{minSdk: 0, err: err}
	}
	usesSdk := usesSdkTag{MinSdk: ""}
	manifest := manifestTag{UsesSdk: usesSdk}
	if err := xml.Unmarshal(manifestBytes, &manifest); err != nil {
		return result{minSdk: 0, err: err}
	}

	// MinSdk value could be a placeholder, we ignore it if that's the case
	value, err := strconv.Atoi(manifest.UsesSdk.MinSdk)
	if err != nil {
		return result{minSdk: 0, err: nil}
	}
	return result{minSdk: value, err: nil}
}

func writeManifest(outManifest io.Writer, javaPackage string, minSdk int) error {
	manifestWriter := bufio.NewWriter(outManifest)
	manifestWriter.WriteString(fmt.Sprintf(manifestContent, javaPackage, minSdk))
	return manifestWriter.Flush()
}

func max(a, b int) int {
	if a < b {
		return b
	}
	return a
}
