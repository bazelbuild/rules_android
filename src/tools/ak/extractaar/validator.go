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

package extractaar

import (
	"fmt"
	"path/filepath"
	"strings"
)

func boolToString(b bool) string {
	return strings.Title(fmt.Sprintf("%t", b))
}

type validator interface {
	validate(files []*aarFile) ([]*toCopy, *BuildozerError)
}

type manifestValidator struct {
	dest string
}

func (v manifestValidator) validate(files []*aarFile) ([]*toCopy, *BuildozerError) {
	var filesToCopy []*toCopy
	seen := false
	for _, file := range files {
		if seen {
			return nil, &BuildozerError{Msg: "More than one manifest was found"}
		}
		seen = true
		filesToCopy = append(filesToCopy, &toCopy{src: file.path, dest: v.dest})
	}
	if !seen {
		return nil, &BuildozerError{Msg: "No manifest was found"}
	}
	return filesToCopy, nil
}

type resourceValidator struct {
	dest     string
	ruleAttr string
	hasRes   tristate
}

func (v resourceValidator) validate(files []*aarFile) ([]*toCopy, *BuildozerError) {
	var filesToCopy []*toCopy
	seen := false
	for _, file := range files {
		seen = true
		filesToCopy = append(filesToCopy,
			&toCopy{src: file.path, dest: filepath.Join(v.dest, file.relPath)},
		)
	}
	if v.hasRes.isSet() {
		if seen != v.hasRes.value() {
			var not string
			if !seen {
				not = "not "
			}
			msg := fmt.Sprintf("%s attribute is %s, but files were %sfound", v.ruleAttr, boolToString(v.hasRes.value()), not)
			return nil, &BuildozerError{Msg: msg, RuleAttr: v.ruleAttr, NewValue: boolToString(seen)}
		}
	}
	return filesToCopy, nil
}
