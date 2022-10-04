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

// Package walk provides an utility function to walk a directory tree collecting and deduping files.
package walk

import (
	"fmt"
	"os"
	"path/filepath"
)

// Files traverses a list of paths and returns a list of all the seen files.
func Files(paths []string) ([]string, error) {
	var files []string
	seen := make(map[string]bool)
	visitFunc := func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if seen[path] {
			return nil
		}
		seen[path] = true
		switch fType := info.Mode(); {
		case fType.IsDir():
			// Do nothing.
		default:
			files = append(files, path)
		}
		return nil
	}
	for _, p := range paths {
		err := filepath.Walk(p, visitFunc)
		if err != nil {
			return nil, fmt.Errorf("got error while walking %s got: %v", p, err)
		}
	}
	return files, nil
}
