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

// jdeps is a command line tool to filter a jdeps proto
package main

import (
	"flag"
	"io/ioutil"
	"log"
	"strings"

	dpb "src/tools/jdeps/proto/deps_go_proto"
	"google.golang.org/protobuf/proto"
)

var (
	in     = flag.String("in", "", "Path to input jdeps file")
	target = flag.String("target", "", "Target suffix to remove from jdeps file")
	out    = flag.String("out", "", "Path to output jdeps file")
)

func main() {
	flag.Parse()
	if *in == "" || *target == "" || *out == "" {
		log.Fatal("Missing required flags. Must specify --in --target --out.")
	}

	bytes, err := ioutil.ReadFile(*in)
	if err != nil {
		log.Fatalf("Error reading input jdeps: %v", err)
	}
	jdeps := &dpb.Dependencies{}
	if err = proto.Unmarshal(bytes, jdeps); err != nil {
		log.Fatalf("Error parsing input jdeps: %v", err)
	}

	newJdeps := proto.Clone(jdeps).(*dpb.Dependencies)
	var deps []*dpb.Dependency
	for _, dep := range jdeps.Dependency {
		if !strings.HasSuffix(dep.GetPath(), *target) {
			deps = append(deps, dep)
		}
	}
	newJdeps.Dependency = deps

	bytes, err = proto.Marshal(newJdeps)
	if err != nil {
		log.Fatalf("Error serializing output jdeps: %v", err)
	}

	err = ioutil.WriteFile(*out, bytes, 0644)
	if err != nil {
		log.Fatalf("Error writing output jdeps: %v", err)
	}
}
