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
)

func TestGroupAARFiles(t *testing.T) {
	tests := []struct {
		name        string
		files       []*aarFile
		expectedMap map[int][]*aarFile
	}{
		{
			name:  "empty aar",
			files: []*aarFile{},
			expectedMap: map[int][]*aarFile{
				manifest: []*aarFile{},
				res:      []*aarFile{},
				assets:   []*aarFile{},
			},
		},
		{
			name: "simple aar",
			files: []*aarFile{
				&aarFile{relPath: "AndroidManifest.xml"},
				&aarFile{relPath: "res/values/strings.xml"},
				&aarFile{relPath: "lint.jar"},
				&aarFile{relPath: "proguard.txt"},
				&aarFile{relPath: "classes.jar"},
				&aarFile{relPath: "assetsdir/values.txt"},
				&aarFile{relPath: "libs/foo.jar"},
				&aarFile{relPath: "resource/some/file.txt"},
				&aarFile{relPath: "assets/some/asset.png"},
			},
			expectedMap: map[int][]*aarFile{
				manifest: []*aarFile{
					&aarFile{relPath: "AndroidManifest.xml"},
				},
				res: []*aarFile{
					&aarFile{relPath: "res/values/strings.xml"},
				},
				assets: []*aarFile{
					&aarFile{relPath: "assets/some/asset.png"},
				},
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			filesMap := groupAARFiles(tc.files)
			if diff := cmp.Diff(tc.expectedMap, filesMap, cmp.AllowUnexported(aarFile{})); diff != "" {
				t.Errorf("groupAARFiles(%v) returned diff (-want, +got):\n%v", tc.files, diff)
			}
		})
	}
}
