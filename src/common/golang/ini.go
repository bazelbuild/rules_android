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

// Package ini provides utility functions to read and write ini files.
package ini

import (
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"sort"
	"strings"
)

func parse(in string) map[string]string {
	m := make(map[string]string)
	lines := strings.Split(in, "\n")
	for i, l := range lines {
		l = strings.TrimSpace(l)
		if len(l) == 0 {
			// Skip empty line
			continue
		}
		if strings.HasPrefix(l, ";") || strings.HasPrefix(l, "#") {
			// Skip comment
			continue
		}
		kv := strings.SplitN(l, "=", 2)
		if len(kv) < 2 {
			log.Printf("Invalid line in ini file at line:%v %q\n", i, l)
			// Skip invalid line
			continue
		}
		k := strings.TrimSpace(kv[0])
		v := strings.TrimSpace(kv[1])
		if ov, ok := m[k]; ok {
			log.Printf("Overwrite \"%s=%s\", duplicate found at line:%v %q\n", k, ov, i, l)
		}
		m[k] = v
	}
	return m
}

func write(f io.Writer, m map[string]string) {
	var keys []string
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		fmt.Fprintf(f, "%s=%s\n", k, m[k])
	}
}

// Read reads an ini file.
func Read(n string) (map[string]string, error) {
	c, err := ioutil.ReadFile(n)
	if err != nil {
		return nil, err
	}
	return parse(string(c)), nil
}

// Write writes an ini file.
func Write(n string, m map[string]string) error {
	f, err := os.Create(n)
	if err != nil {
		return err
	}
	defer f.Close()
	write(f, m)
	return nil
}
