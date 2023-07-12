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

// print_jdeps is a command line tool to print a jdeps proto.
package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"

	dpb "src/tools/jdeps/proto/deps_go_proto"
	"google.golang.org/protobuf/proto"
)

var (
	in = flag.String("in", "", "Path to input jdeps file")
)

func main() {
	flag.Parse()
	if *in == "" {
		log.Fatal("Missing required flags... Must specify --in")
	}

	bytes, err := ioutil.ReadFile(*in)
	if err != nil {
		log.Fatalf("Error reading jdeps: %v", err)
	}
	jdeps := &dpb.Dependencies{}
	if err = proto.Unmarshal(bytes, jdeps); err != nil {
		log.Fatalf("Error parsing jdeps: %v", err)
	}

	for _, dep := range jdeps.Dependency {
		fmt.Println(dep.GetPath())
	}
}
