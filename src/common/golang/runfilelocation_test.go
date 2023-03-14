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

package runfilelocation

import (
	"io/ioutil"
	"testing"
)

func TestValidRunfileLocation(t *testing.T) {
	// Check that Find() returns a valid path to a runfile
	runfilePath := "src/common/golang/a.txt"

	absRunFilePath, err := Find(runfilePath)
	if err != nil {
		t.Errorf("Runfile path through Runfilelocation() failed: %v", err)
	}

	// Check that the path actually exists
	contents, err := ioutil.ReadFile(absRunFilePath)
	text := string(contents)
	if err != nil {
		t.Errorf("Could not read file: %v", err)
	}

	if text != "hello world\n" {
		t.Errorf("Expected 'hello world' in file, got %v instead.", text)
	}
}

func TestInvalidRunfileLocation(t *testing.T) {
	invalidRunfilePath := "src/common/golang/b.txt"

	runfileLocationShouldNotExist, err := Find(invalidRunfilePath)
	if err == nil {
		// If no error, that means the library is not properly detecting invalid runfile paths
		t.Errorf("Expected error: %v should not be a valid path. Returned %v", invalidRunfilePath, runfileLocationShouldNotExist)
	}
}
