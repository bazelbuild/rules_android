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

// Package flags provides extensions to the built-in flag module.
package flags

import (
	"flag"
	"strings"
)

// StringList provides a flag type that parses a,comma,separated,string into a []string.
type StringList []string

func (i *StringList) String() string {
	return strings.Join([]string(*i), ",")
}

// Set sets the flag value.
func (i *StringList) Set(v string) error {
	*i = strings.Split(v, ",")
	return nil
}

// NewStringList creates a new StringList flag
// var someFlag = flags.NewStringList("some_name", "some desc")
func NewStringList(name, help string) *StringList {
	var r StringList
	flag.Var(&r, name, help)
	return &r
}
