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

// Package validatefeaturemanifest is a tool to validate dynamic feature's manifest file.
package validatefeaturemanifest

import (
	"encoding/xml"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"

	"src/tools/ak/types"
)

var (
	Cmd = types.Command{
		Init: Init,
		Run:  Run,
		Desc: desc,
		Flags: []string{
			"manifest",
			"output",
			"is_asset_pack",
		},
	}

	initOnce sync.Once

	manifestFlag    string
	outputFlag      string
	isAssetPackFlag bool
)

// Manifest represents the root <manifest> element
type Manifest struct {
	XMLName  xml.Name  `xml:"manifest"`
	Children []Element `xml:",any"`
}

// Element represents any child element of manifest
type Element struct {
	XMLName xml.Name
	Attrs   []xml.Attr `xml:",any,attr"`
	Content []byte     `xml:",innerxml"`
}

func Init() {
	initOnce.Do(func() {
		flag.StringVar(&manifestFlag, "manifest", "", "AndroidManifest.xml for the dynamic feature")
		flag.StringVar(&outputFlag, "output", "", "Output file to touch on success")
		flag.BoolVar(&isAssetPackFlag, "is_asset_pack", false, "Whether this is an asset pack module")
	})
}

func desc() string {
	return "Validate feature module manifest"
}

func Run() {
	if manifestFlag == "" {
		touchOutput()
		return
	}

	file, err := os.Open(manifestFlag)
	if err != nil {
		log.Fatalf("Error opening manifest: %v", err)
	}
	defer file.Close()

	var manifest Manifest
	decoder := xml.NewDecoder(file)
	if err := decoder.Decode(&manifest); err != nil {
		log.Fatalf("Error parsing manifest XML: %v", err)
	}

	nodeCount := len(manifest.Children)
	moduleCount := 0
	applicationCount := 0
	applicationAttrCount := 0
	applicationHasContent := false
	moduleTitle := ""

	for _, child := range manifest.Children {
		localName := child.XMLName.Local

		if localName == "module" {
			moduleCount++
			for _, attr := range child.Attrs {
				if attr.Name.Local == "title" {
					moduleTitle = attr.Value
					break
				}
			}
		}

		if localName == "application" {
			applicationCount++
			applicationAttrCount = len(child.Attrs)
			applicationHasContent = len(strings.TrimSpace(string(child.Content))) > 0
		}
	}

	valid := false

	if nodeCount == 2 &&
		moduleCount == 1 &&
		applicationCount == 1 &&
		applicationAttrCount == 0 &&
		!applicationHasContent {
		valid = true
	}

	if nodeCount == 1 && moduleCount == 1 {
		valid = true
	}

	if !valid {
		fmt.Println()
		fmt.Printf("%s should only contain a single <dist:module /> element (and optional empty <application/>), nothing else\n", manifestFlag)
		fmt.Println("Manifest contents:")
		content, _ := os.ReadFile(manifestFlag)
		fmt.Println(string(content))
		os.Exit(1)
	}

	if !isAssetPackFlag && moduleTitle != "${MODULE_TITLE}" {
		fmt.Println()
		fmt.Printf("%s dist:title should be ${MODULE_TITLE} placeholder, got: %s\n", manifestFlag, moduleTitle)
		fmt.Println()
		os.Exit(1)
	}

	// Validation passed
	touchOutput()
}

func touchOutput() {
	if outputFlag != "" {
		if err := os.WriteFile(outputFlag, []byte{}, 0644); err != nil {
			log.Fatalf("Error creating output file: %v", err)
		}
	}
}
