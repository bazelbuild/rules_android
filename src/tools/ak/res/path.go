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

package res

import (
	"errors"
	"fmt"
	"path"
	"strings"
)

// ErrNotResPath the provided path does not seem to point to a resource file
var ErrNotResPath = errors.New("Not a resource path")

// ErrSkipResPath the provided path does needs to be skipped.
var ErrSkipResPath = errors.New("resource path that does needs to be skipped")

// PathInfo contains all information about a resource that can be derived from its location on the filesystem.
type PathInfo struct {
	Path      string
	ResDir    string
	TypeDir   string
	Type      Type
	Qualifier string
	Density   Density
}

// ParsePath converts a path string into a PathInfo object if the string points to a resource file.
func ParsePath(p string) (PathInfo, error) {
	parent := path.Dir(p)
	resDir := path.Dir(parent)
	typeDir := path.Base(parent)

	if strings.HasPrefix(path.Base(p), ".") {
		return PathInfo{}, ErrSkipResPath
	}

	resType, err := ParseValueOrType(strings.Split(typeDir, "-")[0])
	qualifier := extractQualifier(typeDir)
	if err != nil {
		return PathInfo{}, ErrNotResPath
	}
	var density Density
	for _, q := range strings.Split(qualifier, "-") {
		var err error
		density, err = ParseDensity(q)
		if err != nil {
			return PathInfo{}, err
		}
		if density != UnspecifiedDensity {
			break
		}
	}
	return PathInfo{
		Path:      p,
		ResDir:    resDir,
		TypeDir:   typeDir,
		Type:      resType,
		Qualifier: qualifier,
		Density:   density,
	}, nil
}

// MakePathInfo converts a path string into a PathInfo object.
func MakePathInfo(p string) (*PathInfo, error) {
	pi, err := ParsePath(p)
	if err != nil {
		return nil, fmt.Errorf("ParsePath failed to parse %q: %v", p, err)
	}
	return &pi, nil
}

// MakePathInfos converts a list of path strings into a list of PathInfo objects.
func MakePathInfos(paths []string) ([]*PathInfo, error) {
	pis := make([]*PathInfo, 0, len(paths))
	for _, p := range paths {
		if strings.HasPrefix(path.Base(p), ".") {
			continue
		}
		pi, err := MakePathInfo(p)
		if err != nil {
			return nil, err
		}
		pis = append(pis, pi)
	}
	return pis, nil
}

func extractQualifier(s string) string {
	base := path.Base(s)
	parts := strings.SplitN(base, "-", 2)
	if len(parts) > 1 {
		return parts[1]
	}
	return ""
}
