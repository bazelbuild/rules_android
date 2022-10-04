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

// Package flagfile installs a -flagfile command line flag.
// This package is only imported for the side effect of installing the flag
package flagfile

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
)

type flagFile string

func (f *flagFile) String() string {
	return string(*f)
}

func (f *flagFile) Get() interface{} {
	return string(*f)
}

func (f *flagFile) Set(fn string) error {
	file, err := os.Open(fn)
	if err != nil {
		return fmt.Errorf("error parsing flagfile %s: %v", fn, err)
	}
	defer file.Close()

	fMap, err := parseFlags(bufio.NewReader(file))
	if err != nil {
		return err
	}
	for k, v := range fMap {
		flag.Set(k, v)
	}
	return nil
}

// parseFlags parses the contents is a naive flag file parser.
func parseFlags(r *bufio.Reader) (map[string]string, error) {
	fMap := make(map[string]string)
	eof := false
	for !eof {
		line, err := r.ReadString('\n')
		if err != nil && err != io.EOF {
			return nil, err
		}
		if err == io.EOF {
			eof = true
		}
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		// When Bazel is used to create flag files, it may create entries that are wrapped within
		// quotations '--a=b'. Verify that it is balanced and strip first and last quotation.
		if strings.HasPrefix(line, "'") || strings.HasPrefix(line, "\"") {
			if !strings.HasSuffix(line, line[:1]) {
				return nil, fmt.Errorf("error parsing flags, found unbalanced quotation marks around flag entry: %s", line)
			}
			line = line[1 : len(line)-1]
		}
		// Check that the flag has at least 1 "-" but no more than 2 ("-a" or "--a").
		if !strings.HasPrefix(line, "-") || strings.HasPrefix(line, "---") {
			return nil, fmt.Errorf("error parsing flags, expected flag start definition ('-' or '--') but, got: %s", line)
		}
		split := strings.SplitN(strings.TrimLeft(line, "-"), "=", 2)
		k := split[0]
		if len(split) == 2 {
			fMap[k] = split[1]
			continue
		}
		v, err := parseFlagValue(r)
		if err != nil {
			return nil, fmt.Errorf("error parsing flag value, got: %v", err)
		}
		fMap[k] = v
	}
	return fMap, nil
}

func parseFlagValue(r *bufio.Reader) (string, error) {
	pBytes, err := r.Peek(2)
	if err != nil && err != io.EOF {
		return "", err
	}
	peeked := string(pBytes)
	// If the next line starts with "-", "'-" or '"-' assume it is the beginning of a new flag definition.
	if strings.HasPrefix(peeked, "-") || peeked == "'-" || peeked == "\"-" {
		return "", nil
	}
	// Next line contains the flag value.
	line, err := r.ReadString('\n')
	if err != nil && err != io.EOF {
		return "", err
	}
	return strings.TrimSpace(line), nil
}

func init() {
	flag.Var(new(flagFile), "flagfile", "Path to flagfile containing flag values, --key=val on each line")
}
