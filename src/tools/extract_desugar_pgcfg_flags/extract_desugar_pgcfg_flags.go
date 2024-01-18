// Copyright 2023 The Bazel Authors. All rights reserved.
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

// Tool for extracting the shrinker_config field from desugar_jdk_libs's json config file.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"
)

var (
	inputJSONFlag  = flag.String("input_json", "", "Path to the R8 desugar_jdk_libs.json file")
	outputFileFlag = flag.String("output_file", "", "Path to the output file for the extracted pgcfg.")
)

func main() {
	flag.Parse()

	// Check that the input and output file flags are populated.
	if *inputJSONFlag == "" {
		log.Fatal("--input_json is required")
	}
	if *outputFileFlag == "" {
		log.Fatal("--output_file is required")
	}

	// Read the input json file
	jsonFile, err := os.Open(*inputJSONFlag)
	if err != nil {
		log.Fatal(err)
	}

	defer jsonFile.Close()

	// Parse the JSON
	jsonBytes, err := ioutil.ReadAll(jsonFile)
	if err != nil {
		log.Fatal(err)
	}

	// The r8 desugar config json schema is pretty complicated (+subject to change), and we only
	// need one field, so instead of reading into a predefined data structure, we just read into a
	// map[string]any to keep things simple.
	var result map[string]any
	json.Unmarshal(jsonBytes, &result)

	// Read the shrinker_config field as a string, then trim the demarcating [ ] characters.
	shrinkerConfigAsString := strings.TrimRight(strings.TrimLeft(fmt.Sprintf("%v", result["shrinker_config"]), "["), "]")
	shrinkerConfigList := strings.Split(shrinkerConfigAsString, " ")
	// Massage into newline-separated flag list.
	shrinkerConfigFlags := strings.Join(shrinkerConfigList, "\n")

	// Write the shrinker config to the output file
	shrinkerConfigFile, err := os.Create(*outputFileFlag)
	if err != nil {
		log.Fatal(err)
	}
	defer shrinkerConfigFile.Close()

	if _, err := shrinkerConfigFile.WriteString(shrinkerConfigFlags); err != nil {
		log.Fatal(err)
	}
}
