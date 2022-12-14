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
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
)

func TestValidateManifest(t *testing.T) {
	tests := []struct {
		name          string
		files         []*aarFile
		dest          string
		expectedFiles []*toCopy
	}{
		{
			name: "one manifest",
			files: []*aarFile{
				&aarFile{path: "/tmp/aar/AndroidManifest.xml"},
			},
			dest: "/dest/outputManifest.xml",
			expectedFiles: []*toCopy{
				&toCopy{src: "/tmp/aar/AndroidManifest.xml", dest: "/dest/outputManifest.xml"},
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			validator := manifestValidator{dest: tc.dest}
			files, err := validator.validate(tc.files)
			if err != nil {
				t.Fatalf("manifestValidator.validate(%s) unexpected error: %v", tc.files, err)
			}
			if diff := cmp.Diff(tc.expectedFiles, files, cmp.AllowUnexported(toCopy{})); diff != "" {
				t.Errorf("manifestValidator.validate(%s) returned diff (-want, +got):\n%v", tc.files, diff)
			}
		})
	}
}

func TestValidateManifestError(t *testing.T) {
	tests := []struct {
		name  string
		files []*aarFile
	}{
		{
			name:  "no manifest",
			files: []*aarFile{},
		},
		{
			name: "multiple manifests",
			files: []*aarFile{
				&aarFile{path: "/tmp/aar/AndroidManifest.xml"},
				&aarFile{path: "/tmp/aar/SecondAndroidManifest.xml"},
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			validator := manifestValidator{}
			if _, err := validator.validate(tc.files); err == nil {
				t.Errorf("manifestValidator.validate(%s) expected error but test succeeded: %v", tc.files, err)
			}
		})
	}
}

func TestValidateResources(t *testing.T) {
	tests := []struct {
		name          string
		files         []*aarFile
		dest          string
		hasRes        tristate
		expectedFiles []*toCopy
	}{
		{
			name: "has resources with valid hasRes attribute",
			files: []*aarFile{
				&aarFile{path: "/tmp/aar/res/values/strings.xml", relPath: "res/values/strings.xml"},
				&aarFile{path: "/tmp/aar/res/layout/activity.xml", relPath: "res/layout/activity.xml"},
			},
			hasRes: tristate(1),
			dest:   "/dest/outputres",
			expectedFiles: []*toCopy{
				&toCopy{src: "/tmp/aar/res/values/strings.xml", dest: "/dest/outputres/res/values/strings.xml"},
				&toCopy{src: "/tmp/aar/res/layout/activity.xml", dest: "/dest/outputres/res/layout/activity.xml"},
			},
		},
		{
			name:          "does not have resources with valid hasRes attribute",
			files:         []*aarFile{},
			hasRes:        tristate(0),
			dest:          "/dest/outputres",
			expectedFiles: nil,
		},
		{
			name:          "no resources and checks disabled",
			files:         []*aarFile{},
			hasRes:        tristate(-1),
			dest:          "/dest/outputres",
			expectedFiles: nil,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			validator := resourceValidator{dest: tc.dest, hasRes: tc.hasRes}
			files, err := validator.validate(tc.files)
			if err != nil {
				t.Fatalf("resourceValidator.validate(%s) unexpected error: %v", tc.files, err)
			}
			if diff := cmp.Diff(tc.expectedFiles, files, cmp.AllowUnexported(toCopy{})); diff != "" {
				t.Errorf("resourceValidator.validate(%s) returned diff (-want, +got):\n%v", tc.files, diff)
			}
		})
	}
}

func TestValidateResourcesError(t *testing.T) {
	tests := []struct {
		name          string
		files         []*aarFile
		hasRes        tristate
		ruleAttr      string
		expectedError *BuildozerError
	}{
		{
			name: "has resources with invalid hasRes attribute",
			files: []*aarFile{
				&aarFile{path: "/tmp/aar/res/values/strings.xml", relPath: "res/values/strings.xml"},
				&aarFile{path: "/tmp/aar/res/layout/activity.xml", relPath: "res/layout/activity.xml"},
			},
			hasRes:        tristate(-1),
			ruleAttr:      "test",
			expectedError: &BuildozerError{RuleAttr: "test", NewValue: "True"},
		},
		{
			name:          "no resources with invalid hasRes attribute",
			files:         []*aarFile{},
			hasRes:        tristate(1),
			ruleAttr:      "test",
			expectedError: &BuildozerError{RuleAttr: "test", NewValue: "False"},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			validator := resourceValidator{ruleAttr: tc.ruleAttr, hasRes: tc.hasRes}
			_, err := validator.validate(tc.files)
			if err == nil {
				t.Fatalf("resourceValidator.validate(%s) expected error but test succeeded: %v", tc.files, err)
			}
			if diff := cmp.Diff(tc.expectedError, err, cmpopts.IgnoreFields(BuildozerError{}, "Msg")); diff != "" {
				t.Errorf("resourceValidator.validate(%s) returned diff (-want, +got):\n%v", tc.files, diff)
			}
		})
	}
}
