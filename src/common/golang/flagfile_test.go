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

// Unit test for the flagfile module.
package flagfile

import (
	"bufio"
	"reflect"
	"strings"
	"testing"
)

func TestParseFlags(t *testing.T) {
	tcs := []struct {
		name    string
		in      string
		want    map[string]string
		wantErr string
	}{
		{
			name: "SingleLineFlagDefinitions",
			in: `
--a=b
'--1=2'
-foo=bar
--enable
"--baz=qux=quux"
`,
			want: map[string]string{
				"a":      "b",
				"1":      "2",
				"foo":    "bar",
				"enable": "",
				"baz":    "qux=quux",
			},
		},
		{
			name: "MultiLineFlagDefinitions",
			in: `
--a
b
--1
2
-foo
bar
--enable
--baz
qux=quux
`,
			want: map[string]string{
				"a":      "b",
				"1":      "2",
				"foo":    "bar",
				"enable": "",
				"baz":    "qux=quux",
			},
		},
		{
			name: "MixedMultiSingleLineFlagDefinitions",
			in: `
--a
b
"-1=2"
-foo
bar
--enable
'--baz=--qux=quux'
`,
			want: map[string]string{
				"a":      "b",
				"1":      "2",
				"foo":    "bar",
				"enable": "",
				"baz":    "--qux=quux",
			},
		},
		{
			name: "NoFlags",
			in:   "",
			want: map[string]string{},
		},
		{
			name:    "MalformedFlagMissingDash",
			in:      "a=b",
			wantErr: "expected flag start definition ('-' or '--')",
		},
		{
			name:    "MalformedFlagTooManyDashes",
			in:      "---a=b",
			wantErr: "expected flag start definition ('-' or '--')",
		},
		{
			name:    "UnbalancedQuotationsAroundFlag",
			in:      "'--a=b",
			wantErr: "found unbalanced quotation marks around flag entry",
		},
	}
	for _, tc := range tcs {
		t.Run(tc.name, func(t *testing.T) {
			got, err := parseFlags(bufio.NewReader(strings.NewReader(tc.in)))
			if err != nil {
				if tc.wantErr != "" {
					if !strings.Contains(err.Error(), tc.wantErr) {
						t.Errorf("error got error: %s wanted to contain: %s", err, tc.wantErr)
					}
					return
				}
				t.Errorf("got unexpected error: %s", err)
				return
			}
			if eq := reflect.DeepEqual(got, tc.want); !eq {
				t.Errorf("error got: %v wanted: %v", got, tc.want)
			}
		})
	}
}
