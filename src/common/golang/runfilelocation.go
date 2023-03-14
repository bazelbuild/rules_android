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

// Package runfilelocation provides utility functions to deal with runfiles

package runfilelocation

import (
	"os"
	"path"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

// Find determines the absolute path to a given runfile
func Find(runfilePath string) (string, error) {
	runfileLocation, err := runfiles.Rlocation(path.Join(os.Getenv("TEST_WORKSPACE"), runfilePath))

	if err != nil {
		return "", err
	}

	// Check if file exists
	if _, err := os.Stat(runfileLocation); err != nil {
		return "", err
	}

	return runfileLocation, err
}
